<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {

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

    #Load Public Functions after prerequisites
    . $BuildRoot\PowerCD\Public\Initialize-PowerCD.ps1

    Initialize-PowerCD

    $GetBuildEnvironmentParams = @{
        GitPath = (get-command git -CommandType application)
    }
}