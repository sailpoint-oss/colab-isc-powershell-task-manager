# This method is used to load the environment variables for the SDK. 
# ConvertFrom-SecureString -SecureString $(Read-Host -AsSecureString)

function Initialize-Token () {
    try{
        $env:SAIL_BASE_URL="https://$($script:GLOBAL_CONFIG.General.tenant).api.$($script:GLOBAL_CONFIG.General.domain).com"
        $env:SAIL_CLIENT_ID=$script:GLOBAL_CONFIG.Authentication."$($script:GLOBAL_CONFIG.General.tenant)".clientID
        
        $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $script:GLOBAL_CONFIG.Authentication."$($script:GLOBAL_CONFIG.General.tenant)".clientID, $($script:GLOBAL_CONFIG.Authentication."$($script:GLOBAL_CONFIG.General.tenant)".clientSecret | ConvertTo-SecureString) 
        $env:SAIL_CLIENT_SECRET=$credentials.GetNetworkCredential().password
    } catch {
        Write-Log $_ 1
        EXIT 1
    }
}