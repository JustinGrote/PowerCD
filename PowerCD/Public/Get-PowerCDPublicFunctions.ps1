<#
.SYNOPSIS
Fetch the names of public functions in the specified folder using AST
.DESCRIPTION
This is a better method than grabbing the names of the .ps1 file and "hoping" they line up.
This also only gets parent functions, child functions need not apply
#>

function Get-PowerCDPublicFunctions {
    [CmdletBinding()]
    param(
        #The path to the public module directory containing the modules. Defaults to the "Public" folder where the source module manifest resides.
        [String]$PublicModulePath = (Join-Path (Split-Path $pcdSetting.Environment.PSModuleManifest) 'Public')
    )

    $PublicFunctionCode = Get-ChildItem $PublicModulePath -Filter '*.ps1' | Get-Content -Raw

    [ScriptBlock]::Create($PublicFunctionCode).AST.EndBlock.Statements | Where-Object {
        $PSItem -is [Management.Automation.Language.FunctionDefinitionAst]
    } | Foreach-Object Name
}