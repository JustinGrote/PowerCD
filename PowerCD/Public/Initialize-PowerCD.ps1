<#
.SYNOPSIS
Initializes the build environment and detects various aspects of the environment
#>

function Initialize-PowerCD {
    [CmdletBinding()]
    param (
        #Specify this if you don't want initialization to switch to the folder build root
        [Switch]$SkipSetBuildRoot
    )

    try {
        Import-Module BuildHelpers -ErrorAction Stop
    } catch {
        Import-PowerCDModuleFast BuildHelpers -Erroraction Stop
    }

    . $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Script -Option ReadOnly -Force -Value (Get-PowerCDSetting)

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($pcdsetting.environment.buildsystem -and $pcdsetting.environment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = "SilentlyContinue"
    }
}
