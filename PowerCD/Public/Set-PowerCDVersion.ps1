<#
.SYNOPSIS
Sets the version on a powershell Module
#>
function Set-PowerCDVersion {
    [CmdletBinding()]
    param (
        #Path to the module manifest to update
        [String]$Path = $PCDSetting.OutputModuleManifest,
        #Version to set for the module
        [Version]$Version = $PCDSetting.Version,
        #Prerelease tag to add to the module, if any
        [String]$PreRelease= $PCDSetting.Prerelease
    )
    #Default is to update version so no propertyname specified
    #FIXME: DEBUG Item
    import-module C:\Users\VssAdministrator\AppData\Local\Temp\PowerCD\BuildHelpers\2.0.11\BuildHelpers.psd1 -force
    BuildHelpers\Update-Metadata -Path $Path -Value $Version

    BuildHelpers\Update-Metadata -Path $Path -PropertyName PreRelease -Value $PreRelease
}