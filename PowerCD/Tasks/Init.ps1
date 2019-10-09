<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {
    #Check for variable overrides and apply them.
    #TODO: Handle this better
    $UserPrefs = Import-PowershellDataFile .\PSModule.build.psd1

    #These variables are used by nearly every task to determine context
    $GetBuildEnvironmentParams = @{
        GitPath = (get-command git -CommandType application)
    }
    if ($UserPrefs.BuildOutput) { $GetBuildEnvironmentParams.BuildOutput = $UserPrefs.BuildOutput }

    Set-Variable PCDBuildEnvironment -Scope Script -Value (Get-BuildEnvironment @GetBuildEnvironmentParams)
}