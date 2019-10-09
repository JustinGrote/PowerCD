<#
.SYNOPSIS
This task performs initialization and prepares shared variables for other PowerCD tasks. It is required for all powercd tasks.
#>
param (
    #Specify an alternate BuildOutput Directory
    $BuildOutput
)

task Init.PowerCD {
    . $PSSCRIPTROOT\..\Public\Initialize-PowerCD.ps1
    Initialize-PowerCD
}