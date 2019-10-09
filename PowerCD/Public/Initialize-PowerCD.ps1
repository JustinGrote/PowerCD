#requires -module BuildHelpers
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
    Get-BuildEnvironment



    #Appveyor Detection
    if ($ENV:APPVEYOR) {Set-Variable -Name IsAppVeyor -Scope 1 -Value $true}
    #Azure DevOps Detection
    if ($ENV:SYSTEM_COLLECTIONID) {Set-Variable -Name IsAzureDevOps -Scope 1 -Value $true}

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or $IsAppVeyor -or $IsAzureDevOps -or ([Environment]::GetCommandLineArgs() -like '-noni*')) {
        write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow
        $ProgressPreference = "SilentlyContinue"
    }
}
