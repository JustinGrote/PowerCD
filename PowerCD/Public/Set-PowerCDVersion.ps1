<#
.SYNOPSIS
Sets the version on a powershell Module
#>
#Requires -module BuildHelpers
function Set-PowerCDVersion {
    [CmdletBinding()]
    param (
        #Path to the module manifest to update
        [String]$Path,
        #Version to set for the module
        [Version]$Version,
        #Prerelease tag to add to the module, if any
        [String]$PreRelease
    )


}