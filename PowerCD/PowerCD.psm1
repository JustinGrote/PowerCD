#region SourceInit
$publicFunctions = @()
foreach ($ScriptPathItem in 'Private','Public') {
    $ScriptSearchFilter = [io.path]::Combine($PSScriptRoot, $ScriptPathItem, '*.ps1')
    Get-ChildItem $ScriptSearchFilter | Foreach-Object {
        if ($ScriptPathItem -eq 'Public') {$PublicFunctions += $PSItem.BaseName}
        . $PSItem
    }
}
#endregion SourceInit

#Module Startup
Set-Alias PowerCD.Tasks $PSScriptRoot/PowerCD.tasks.ps1

if (-not $PublicFunctions) {
    $ModuleManifest = Join-Path $PSScriptRoot 'PowerCD.psd1'
    # $PublicFunctions = if (Get-Command Import-PowershellDataFile -ErrorAction Silently Continue) {
    #     Import-PowershellDataFile -Path $ModuleManifest
    # } else {

    #     #Some Powershell Installs don't have microsoft.powershell.utility for some reason.
    #     #TODO: Bootstrap microsoft.powershell.utility maybe?
    #     #Last Resort
    #     #Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'powercd.psd1'
    # }
    $PublicFunctions = Import-PowershellDataFile -Path $ModuleManifest
    Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions.FunctionsToExport
}

Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions
