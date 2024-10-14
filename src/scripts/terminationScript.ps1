$script:NAME = "Termination Script"
function Invoke-Action ($account) {
    try {
        $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
        Write-Log "$script:NAME has started."

        # Place Logic Here
        throw "Couldn't find user."

        Write-Log "$script:NAME has finished."
        return [RunResponse]::new("COMPLETED", $null)
    } catch {
        return [RunResponse]::new("NO_RETRY", "($start) $_")
    }
}