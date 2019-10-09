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

    $erroractionPreference = 'Stop'
    write-host -fore magenta "Checking for BuildHelpers"

    function FastImportModule ($ModuleName) {
        process {
            #Get a temporary directory
            $tempFilePath = [System.IO.Path]::GetTempFileName()
            $tempfile = $tempFilePath -replace '\.tmp$','.zip'
            $tempdir = Split-Path $tempfilePath -Parent

            #Fetch Invoke-Build and import the module

            $invokeBuildLatestURI = "https://powershellgallery.com/api/v1/package/$ModuleName"
            write-verbose "Fetching $ModuleName from $invokeBuildLatestURI"
            (New-Object Net.WebClient).DownloadFile($invokeBuildLatestURI, $tempfile)

            $CurrentProgressPreference = $ProgressPreference
            $GLOBAL:ProgressPreference = 'silentlycontinue'
            Expand-Archive $tempfile $tempdir -Force -ErrorAction stop
            $GLOBAL:ProgressPreference = $CurrentProgressPreference

            $ModuleToImportPath = Join-Path $tempdir "$ModuleName.psd1"
            write-verbose "Importing $ModuleName from $ModuleToImportPath"
            Import-Module $ModuleToImportPath -force
        }
    }

    try {
        Import-Module BuildHelpers -ErrorAction Stop
    } catch {
        FastImportModule BuildHelpers -Erroractionstop
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
