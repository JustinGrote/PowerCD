<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {
    function FastImportModule ($ModuleName) {
        process {
            #Get a temporary directory
            $tempFilePath = [System.IO.Path]::GetTempFileName()
            $tempfile = $tempFilePath -replace '\.tmp$','.zip'
            $tempdir = Split-Path $tempfilePath -Parent

            #Fetch Invoke-Build and import the module
            $invokeBuildLatestURI = "https://powershellgallery.com/api/v1/package/$ModuleName"
            (New-Object Net.WebClient).DownloadFile($invokeBuildLatestURI, $tempfile)

            $CurrentProgressPreference = $ProgressPreference
            $GLOBAL:ProgressPreference = 'silentlycontinue'
            Expand-Archive $tempfile $tempdir -Force -ErrorAction stop
            $GLOBAL:ProgressPreference = $CurrentProgressPreference

            $ModuleToImportPath = Join-Path $tempdir "$ModuleName.psd1"
            Import-Module $ModuleToImportPath -force
        }
    }

    try {
        Import-Module BuildHelpers -ErrorAction Stop
    } catch {
        FastImportModule BuildHelpers
    }

    Initialize-PowerCD

    $GetBuildEnvironmentParams = @{
        GitPath = (get-command git -CommandType application)
    }

}