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
    write-host -fore magenta "PSScriptRoot: $PSScriptRoot"
    $publicFunctions = (Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'powercd.psd1').FunctionsToExport
    Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions
}

Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions
