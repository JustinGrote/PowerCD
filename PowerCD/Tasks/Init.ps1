<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {


    Set-Variable -Name PCDSetting -Option ReadOnly -Value (Get-PowerCDSetting)

    $GetBuildEnvironmentParams = @{
        GitPath = (get-command git -CommandType application)
    }
    if ($UserPrefs.BuildOutput) { $GetBuildEnvironmentParams.BuildOutput = $UserPrefs.BuildOutput }

    Set-Variable PCDBuildEnvironment -Scope Script -Value (Get-BuildEnvironment @GetBuildEnvironmentParams)
}