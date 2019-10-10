<#
.SYNOPSIS
This function sets a module manifest for the various function exports that are present in a module such as private/public functions, classes, etc.
#>

function Update-PowerCDPublicFunctions {
    param(
        #Path to the module manifest to update
        [String]$Path = $PCDSetting.OutputModuleManifest,
        #Specify to override the auto-detected function list
        [String[]]$Functions = $PCDSetting.Functions,
        #Paths to the module public function files
        [String]$PublicFunctionPath = (Join-Path $PCDSetting.Environment.ModulePath 'Public')
    )

    if (-not $Functions) {
        write-verbose "Autodetecting Public Functions in $Path"
        $Functions = Get-PowerCDPublicFunctions $PublicFunctionPath
    }


    Update-Metadata -Path $Path -PropertyName FunctionsToExport -Value $Functions
}