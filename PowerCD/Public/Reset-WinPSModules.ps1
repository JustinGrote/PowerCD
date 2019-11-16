function Reset-WinPSModules {
    if ($PSEdition -eq 'Desktop') {
        Get-Module | Where-Object CompatiblePSEditions -eq 'Core' | foreach {
            $moduleToImport = Get-Module $PSItem.Name -ListAvailable | Where-Object CompatiblePSEditions -match 'Desktop' | Sort-Object Version -Descending | Select-Object -First 1
            if ($moduleToImport) {
                write-verbose "Reloading $($PSItem.Name) with Windows Powershell-compatible version $($moduleToImport.version)"
                Remove-Module $PSItem
                Import-Module $moduleToImport -Force -Verbose:$false
            } else {
                throw "A core-only version of the $($PSItem.Name) module was detected as loaded and no Windows Powershell Desktop-compatible equivalent was found in the PSModulePath. Please copy a Desktop-Compatible version of the module to your PSModulePath."
            }
        }
    }
}