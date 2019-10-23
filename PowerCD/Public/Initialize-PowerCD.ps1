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

    #Import Prerequisites
    Import-PowerCDRequirement @(
        'Pester'
        'BuildHelpers'
        'PSScriptAnalyzer'
    )
    Import-PowerCDRequirement -ModuleName PowerConfig -Version '0.1.0-beta0001'

    #Start a new PowerConfig, using PowerCDSetting as a base
    $PCDConfig = New-PowerConfig | Add-PowerConfigObject -Object (Get-PowerCDSetting)

    #. $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Global -Option ReadOnly -Force -Value ($PCDConfig | Get-PowerConfig)

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($PCDSetting.BuildEnvironment.buildsystem -and $PCDSetting.BuildEnvironment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = "SilentlyContinue"
    }
}
