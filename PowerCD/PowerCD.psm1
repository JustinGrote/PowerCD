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

Set-Alias PowerCD.Tasks $PSScriptRoot/PowerCD.tasks.ps1
Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions