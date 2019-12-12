#requires -version 5.1
using namespace System.IO

<#
.SYNOPSIS
Bootstraps Invoke-Build and starts it with supplied parameters.
.NOTES
If you already have Invoke-Build installed, just use Invoke-Build instead of this script. This is for CI/CD environments like Appveyor, Jenkins, or Azure DevOps pipelines.
.EXAMPLE
.\build.ps1
Starts Invoke-Build with the default parameters
#>

$ErrorActionPreference = 'Stop'
. ./PowerCD.buildinit.ps1
$SCRIPT:PowerCDBuildInit = $true
Invoke-Build $args