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
    Configuration\Update-Metadata -Path $Path -Value $Version

    Configuration\Update-Metadata -Path $Path -PropertyName PreRelease -Value $PreRelease
}