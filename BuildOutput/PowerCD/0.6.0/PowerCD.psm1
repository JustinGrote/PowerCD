echo "Before"

#region SourceInit
$PublicScriptPath = [io.path]::Combine($PsScriptRoot, 'Public', '*.ps1')
foreach ($ScriptItem in Get-ChildItem $PublicScriptPath) {
    . $ScriptItem
}
#endregion SourceInit

echo "After"
