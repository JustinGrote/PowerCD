<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {
    try {
        Import-Module BuildHelpers -ErrorAction Stop
    } catch {
        Install-Module BuildHelpers -scope currentuser -force
    }

    Initialize-PowerCD

    $GetBuildEnvironmentParams = @{
        GitPath = (get-command git -CommandType application)
    }

}