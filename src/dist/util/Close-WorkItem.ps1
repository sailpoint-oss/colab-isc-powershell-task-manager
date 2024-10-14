function Close-WorkItem ($id) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Content-Type", "application/json")

    try {
        $Token = Get-IDNAccessToken
        $headers.Add("Authorization", "Bearer $($Token)")
    } catch {
        Write-Host $_ -ForegroundColor Yellow
        return
    }
    
    $response = Invoke-RestMethod "https://$($script:GLOBAL_CONFIG.General.tenant).api.$($script:GLOBAL_CONFIG.General.domain).com/v2024/work-items/$($id)" -Method 'POST' -Headers $headers -Body $null
    return ($response)
}