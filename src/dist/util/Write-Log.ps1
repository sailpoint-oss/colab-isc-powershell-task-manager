# This method is to update the log file for logging purposes
function Write-Log ([string]$LogString, $level, $console){
    if ($null -eq $level) { $level = 2 }
    if ($level -gt $script:GLOBAL_CONFIG.General.logLevel -or $script:GLOBAL_CONFIG.General.logLevel -eq 0) { return }

    $levelDescriptors = $("ERROR", "INFO", "DEBUG")
    $levelColors = $("Red", "Blue", "Green")
    $Stamp = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
    $LogMessage = "($Stamp) [$($levelDescriptors[$level-1])] $LogString"
    $LogMessage | Out-File -FilePath $script:LOG_FILE_NAME -Append
    if ($console -eq $true -or $script:GLOBAL_CONFIG.General.logLevel -ge 3) {
        Write-Host $LogMessage -ForegroundColor ($levelColors[$level-1])
    }
}
