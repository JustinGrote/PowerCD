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
#PowerCD.Tasks may be in different folders, hence why we do the search here
Set-Alias PowerCD.Tasks ([String](Get-ChildItem -recurse $PSScriptRoot -include PowerCD.tasks.ps1)[0])

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
