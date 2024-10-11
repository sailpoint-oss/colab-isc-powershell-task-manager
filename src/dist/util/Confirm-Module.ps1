function Confirm-Module ($name, $version) {
    # If module is imported say that and do nothing
    if (Get-Module -FullyQualifiedName $(@{ModuleName=$name;ModuleVersion=$version})) {
        #Write-Host "Required module $name is already imported."
    }
    else {
        # If module is not imported, but available on disk
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $name}) {
            Import-Module $name -RequiredVersion $version
        }
        else {
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $name | Where-Object {$_.Name -eq $name}) {
                Write-Log "Required module $name version $version or higher is not installed/imported. Try running ""Install-Module -Name $name -Force -Verbose -Scope CurrentUser; Import-Module $name"" and retrying." -ForegroundColor Red
                EXIT 1
            }
            else {
                # If the module is not imported, not available and not in the online gallery then abort
                Write-Log "Required module $name is not installed/imported, not available and not in an online gallery, exiting." -ForegroundColor Red
                EXIT 1
            }
        }
    }
}