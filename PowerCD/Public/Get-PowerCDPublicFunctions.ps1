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
        [String]$PublicModulePath = (Join-Path (Split-Path $PCDSetting.BuildEnvironment.PSModuleManifest) 'Public')
    )

    $PublicFunctionCode = Get-ChildItem $PublicModulePath -Filter '*.ps1'

    #using statements have to be first, so we have to pull them out and move them to the top
    [String[]]$UsingLines = @()
    [String]$PublicFunctionCodeWithoutUsing = (Get-Content $PublicFunctionCode.FullName | Where-Object {
        if ($_ -match '^using .+$') {
            $UsingLines += $_
            return $false
        }
        return $true
    }) -join [Environment]::NewLine

    #Rebuild PublicFunctionCode with a stringbuilder to put all the using up top
    [Text.StringBuilder]$PublicFunctionCode = ''
    $UsingLines | Select-Object -Unique | Foreach-Object {
        [void]$PublicFunctionCode.AppendLine($PSItem)
    }
    [void]$PublicFunctionCode.AppendLine($PublicFunctionCodeWithoutUsing)

    [ScriptBlock]::Create($PublicFunctionCode).AST.EndBlock.Statements | Where-Object {
        $PSItem -is [Management.Automation.Language.FunctionDefinitionAst]
    } | Foreach-Object Name
}