$script:SCRIPT_PATH = "C:\SailPoint\Scripts\powershell-task-manager"

$runtime = Measure-Command -Expression { 
    <#######################################################################
    ############          Import Dependencies and Setup         ############
    #######################################################################>
    try {
        # Declare Global Script Variables
        $script:GLOBAL_CONFIG = (Get-Content -path "$($script:SCRIPT_PATH)\config.json" | ConvertFrom-Json)

        $script:LOG_FILE_NAME = "$($script:SCRIPT_PATH)\log\$((Get-Date).toString("MM-dd-yyyy_HHmmss"))_$($script:GLOBAL_CONFIG.General.logFileName).log"

        # Import Log Method
        . "$($script:SCRIPT_PATH)\dist\util\Write-Log.ps1"
        Write-Log "Loading script dependencies..."

        # Import necessary helper functions
        foreach ($file in Get-ChildItem "$script:SCRIPT_PATH\dist" -Recurse) {
            if ($file.PSIsContainer -or $file.Name -eq "Write-Log.ps1") { continue }
            Write-Log "Importing file $($file.Name)."
            . "$($file.FullName)"
        }

        Confirm-Module "PSSailPoint" $script:GLOBAL_CONFIG.General.sdkVersion

        # Set PAT environment variables.
        Initialize-Token
    }
    catch {
        Write-Log "Unable to load script: $_" 1
        exit
    }

    <#######################################################################
    ############                   Main Script                  ############
    #######################################################################>
    function Main () {
        try {
            # Initialize Stats Class
            $scriptStats = [ScriptStats]::new()

            # Fetch Open Tasks
            $allWorkItems = [System.Collections.ArrayList] @()
            $allWorkItems += (Invoke-Paginate -Function Get-V2024WorkItems -Increment 250 -Limit 30000 -InitialOffset 0)

            # Exit Script If No Tasks
            if ($allWorkItems.Count -le 0 -or $null -eq $allWorkItems[0]) {
                Write-Log "No work items found."
                return
            }

            # Iterate Work Items
            foreach ($workItem in $allWorkItems) {
                Write-Log "Processing Work Item: $($workItem.id)"

                # Initialize New Task Entry
                $taskEntry = [TaskEntry]::new($null, $null, $null, $null, $null)
                # Initalize Closability (Initial value is true and will be altered if a task can be retried.)
                $canCloseWorkItem = $true
                $forceCloseWorkItem = $false

                # Add Statistics
                $scriptStats.AddWorkItem($workItem.id)

                # Iterate the Approval Items
                foreach ($approvalItem in $workItem.approvalItems) {
                    # Initialize Variables for Readability
                    $action = $approvalItem.value
                    $account = $approvalItem.account
                    $operation = $approvalItem.operation

                    # Check if correct source
                    if ($approvalItem.application -ne $script:GLOBAL_CONFIG.Script.applicationName + " [source]") { continue }       
                    # Ensure is pending, add/create/remove operation, and action
                    if ($operation -ne "Create" -and $operation -ne "Add" -and $operation -ne "Remove") { continue }
                    # Ensure we haven't run this before (duplicate prevention)
                    if ($scriptStats.HasAction($account, $action)) { continue }
                    # Check if needs to be closed
                    if ($approvalItem.name -ne "actions" -or $null -eq $action) {
                        $forceCloseWorkItem = $true
                        continue
                    }

                    # Add Statistics
                    $scriptStats.AddAction($account, $action)

                    Write-Log "Processing Approval Item: $action - $account"

                    # Set the id of the task to the account.
                    $taskEntry.SetId($account)
                    
                    # Check if the current account exists.
                    $currentAccount = Get-V2024Accounts -Filters "sourceId eq `"$($script:GLOBAL_CONFIG.Script.sourceId)`" and nativeIdentity eq `"$account`""
                    if ($null -ne $currentAccount) {
                        Write-Log "Found current account: $($currentAccount.id)"
                        $currentAccountTaskEntry = [TaskEntry]::new($currentAccount.attributes.id, $currentAccount.attributes.actions, $currentAccount.attributes.statuses, $currentAccount.attributes.transactions, $currentAccount.attributes.errors)
                        $currentActionStatus = $currentAccountTaskEntry.GetStatus($action)

                        Write-Log "Current Action Status ($action): $currentActionStatus"

                        # If remove, run a reset action.
                        if ($operation -eq "Remove") {
                            if ($currentActionStatus -ne "RESET") {
                                Write-Log "$action has operation of $operation and will be reset." 3
                                $taskEntry.ResetAction($action)
                            } else {
                                Write-Log "$action has operation of $operation and is already reset." 3
                            }
                            continue
                        }

                        # If current status is not to be retried, skip
                        if ($currentActionStatus -eq "NO_RETRY" -or $currentActionStatus -eq "COMPLETED") {
                            Write-Log "$action has status of $currentActionStatus and will not be processed." 3

                            # Remove statistics since we stopped processing
                            $scriptStats.RemoveAction($account, $action)
                            continue
                        }
                    }

                    $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
                    # Load Run-Action method from script.
                    [void] (. "$($script:SCRIPT_PATH)\scripts\$($script:GLOBAL_CONFIG.Script.actions."$action")")

                    # Run the action.
                    try {
                        $run = Invoke-Action $taskEntry.id $start
                    } catch {
                        $run = [RunResponse]::new("NO_RETRY", ($_ | Out-String))
                    }
                    $end = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")

                    Write-Log "$action started on $start and ended on $end with the results of $($run.status) $(if ($null -ne $run.errorMessage) {$run.errorMessage})" 
                    
                    # If end runs, add action to list. 
                    if ($run.status -eq "NO_RETRY" -or $run.status -eq "COMPLETED") { 
                        $taskEntry.AddAction($action)
                    } else {
                        $canCloseWorkItem = $false
                    }

                    # Update the task entry.
                    $taskEntry.UpdateStatus($action, $run.status)
                    $taskEntry.AddTransaction($action, $run.status, $start, $end)
                    if ($null -ne $run.errorMessage) { $taskEntry.AddError($action, $run.errorMessage) }
                }

                # If task ID is not filled, skip. 
                if ([string]::IsNullOrEmpty($taskEntry.id)) { 
                    if ($forceCloseWorkItem -eq $true) {
                        $res = Close-WorkItem -Id $workItem.id 
                        Write-Log "Work item $($workItem.id) has been closed by force."
                    }                    
                    continue 
                }

                # Check if current account exists
                $currentAccount = Get-V2024Accounts -Filters "sourceId eq `"$($script:GLOBAL_CONFIG.Script.sourceId)`" and nativeIdentity eq `"$($taskEntry.id)`""
                if ($null -eq $currentAccount) {
                    # Create New Account on IDN
                    Write-Log "Creating IDN record for $($taskEntry.id): $($taskEntry.actions -join ",")"
                    Write-Log ($taskEntry | Out-String) 3

                    $accountAttributesCreate = Initialize-AccountAttributesCreate -Attributes ($taskEntry.ConvertForCreate())
                    $res = New-V2024Account -AccountAttributesCreate $accountAttributesCreate

                    Write-Log "Created account with id $($res.id)"
                } else {
                    # Update Account on IDN
                    Write-Log "Found current account: $($currentAccount.id)"
                    $currentAccountTaskEntry = [TaskEntry]::new($currentAccount.attributes.id, $currentAccount.attributes.actions, $currentAccount.attributes.statuses, $currentAccount.attributes.transactions, $currentAccount.attributes.errors)

                    $taskEntry.Merge($currentAccountTaskEntry)

                    Write-Log ($taskEntry | Out-String) 3

                    $attributes = Initialize-AccountAttributes -Attributes ($taskEntry.ConvertForUpdate())
                    $res = Send-V2024Account -Id $currentAccount.id -AccountAttributes $attributes

                    Write-Log "Updated account id $($taskEntry.id)"
                }

                # Close the task
                if ($canCloseWorkItem -eq $true) {
                    $res = Close-WorkItem -Id $workItem.id -WithHttpInfo -Verbose -Debug
                    Write-Log "Work item $($workItem.id) has been closed."
                } else {
                    Write-Log "One or more actions failed and will be retried. The work item $($workItem.id) will not be closed."
                }
            }

            $scriptStats.Print()
        } catch {
            Write-Log ($_ | Out-String) 1
        }
    }

    Write-Log "Starting script processing..."
    # Run Main Function
    Main
    Write-Log "Finished script processing."
}

Write-Log "The script took $($runtime.ToString("c")) to finish."