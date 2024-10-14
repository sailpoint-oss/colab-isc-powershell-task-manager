class TaskEntry {
    [string] $id
    [string] $sourceId
    [System.Collections.ArrayList] $actions
    [System.Collections.ArrayList] $statuses # Available Status: COMPLETED, ERROR, NO_RETRY, RESET
    [System.Collections.ArrayList] $transactions
    [System.Collections.ArrayList] $errors

    TaskEntry ($id = $null, $actions = $null, $statuses = $null, $transactions = $null, $errors = $null) {
        if ($null -ne $id) { $this.id = $id } else { $this.id = $null }
        if ($null -ne $actions) { $this.actions = $actions } else { $this.actions = [System.Collections.ArrayList]@() }
        if ($null -ne $statuses) { $this.statuses = $statuses } else { $this.statuses = [System.Collections.ArrayList]@() }
        if ($null -ne $transactions) { $this.transactions = $transactions } else { $this.transactions = [System.Collections.ArrayList]@() }
        if ($null -ne $errors) { $this.errors = $errors } else { $this.errors = [System.Collections.ArrayList]@() }

        $this.sourceId = $script:GLOBAL_CONFIG.Script.sourceId
    }

    [void] SetId ([string] $id) {
        $this.id = $id
    }

    hidden [string] FormatStatus ([string] $action, [string] $status) {
        return "${action}: ${status}"
    }

    [string] GetStatus ([string] $action) {
        if (-not ($this.statuses -join ",").Contains($action)) { return $null }

        foreach ($status in $this.statuses) {
            if ($status.Contains($action)) {
                return ($status.Split(": ")[1])
            }
        }

        return $null
    }

    # Adds or updates an existing status
    [void] UpdateStatus ([string] $action, [string] $status) {
        if (($this.statuses -join ",").Contains($action)) {
            foreach ($s in $this.statuses) {
                if ($s.Contains($status)) {
                    $s = $this.FormatStatus($action, $status)
                    break
                }
            }
        } else {
            [void] $this.statuses.Add($this.FormatStatus($action, $status))
        }
    }

    # Adds an action
    [void] AddAction ([string] $action) {
        if ($this.actions.Contains($action)) { return }
        [void] $this.actions.Add($action)
    }

    # Adds a transaction
    [void] AddTransaction ([string] $action, [string] $status, [string] $startTime, [string] $endTime) {
        if ($status -eq "RESET") { $strStatus = "reset" } elseif ($status -eq "COMPLETED") { $strStatus = "pass" } else { $strStatus = "fail" }
        $transaction = "$action ($strStatus): $startTime - $endTime"
        [void] $this.transactions.Add($transaction)
    }

    # Adds an error
    [void] AddError ([string] $action, [string] $err) {
        $errorMessage = "${action}: $err"
        [void] $this.errors.Add($errorMessage)
    }

    # Runs a reset on an action.
    [void] ResetAction ($action) {
        $this.UpdateStatus($action, "RESET")
        $this.AddTransaction($action, "RESET", (Get-Date).toString("MM-dd-yyyy HH:mm:ss"), (Get-Date).toString("MM-dd-yyyy HH:mm:ss"))
    }

    # Merge one task with this one. 
    [void] Merge ([TaskEntry] $task) {
        # Merge Actions, Except If Action Was Reset
        $this.actions = @($($this.actions; ($task.actions | Where-Object { $null -ne $_ -and -not $this.statuses.Contains($this.FormatStatus($_, "RESET")) })))
        # Merge Statuses, Except If Status Was Changed
        $this.statuses = @($($this.statuses; ($task.statuses | Where-Object { $null -ne $_ -and -not ($this.statuses -join ",").Contains(($_ -split ":")[0]) })))
        # Merge All Transactions
        $this.transactions = @($($this.transactions; ($task.transactions | Where-Object { $null -ne $_ })))
        # Merge All Errors
        $this.errors = @($($this.errors; ($task.errors | Where-Object { $null -ne $_ })))
    }

    [object] ConvertForCreate() {
        return @{
            id = $this.id
            actions = $this.actions
            statuses = $this.statuses
            transactions = $this.transactions
            errors = $this.errors
            sourceId = $this.sourceId
        }
    }

    [object] ConvertForUpdate() {
        return @{
            id = $this.id
            actions = $this.actions
            statuses = $this.statuses
            transactions = $this.transactions
            errors = $this.errors
        }
    }
}