Import-Module ActiveDirectory

$script:NAME = "Email Script"
function Invoke-Action ($account) {
    try {
        $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
        Write-Log "$script:NAME has started."

        $adAccount = Get-ADUser -Filter "description -eq `"$($account)`"" -Properties *
        if ($null -eq $adAccount) { throw "Could not find the AD Account" }

        Set-ADUser -Identity $adAccount.SamAccountName -Email "$($adAccount.SamAccountName)@example.com"

        Write-Log "$script:NAME has finished."
        return [RunResponse]::new("COMPLETED", $null)
    } catch {
        return [RunResponse]::new("ERROR", "($start) $_")
    }
}