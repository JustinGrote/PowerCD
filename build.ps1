#requires -version 5
using namespace System.IO
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Bootstraps Invoke-Build and starts it with supplied parameters.
.NOTES
If you already have Invoke-Build installed, just use Invoke-Build instead of this script. This is for CI/CD environments like Appveyor, Jenkins, or Azure DevOps pipelines.
.EXAMPLE
.\build.ps1
Starts Invoke-Build with the default parameters
#>

function FindInvokeBuild {
	<#
.SYNOPSIS
Returns a path to an Invoke-Build powershell module either as a Powershell Module or in NuGet
#>
	param (
		#Specify the minimum version to accept as installed
		[Version]$MinimumVersion = '5.4.1',
		#Specify this if you know it isn't present as a powershell module and want to save some detection time
		[Switch]$SkipPSModuleDetection,
		#Specify this if you just want a simple true/false result
		[Switch]$Quiet
	)

	if (-not $SkipPSModuleDetection) {
		Write-Verbose "Detecting InvokeBuild as a Powershell Module..."
		$invokeBuild = (Get-Module InvokeBuild -listavailable -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1) | Where-Object version -gt $MinimumVersion
	}

	if (-not $invokeBuild -and (Get-Command Get-Package -erroraction silentlycontinue)) {
		Write-Verbose "InvokeBuild not found as a Powershell Module. Checking for NuGet package..."
		$invokeBuild = Get-Package Invoke-Build -MinimumVersion $MinimumVersion -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1
	}

	if ($InvokeBuild) {

		if ($Quiet) {
			return $false
		} else {
			Write-Host -fore green "Invoke-Build $MinimumVersion is already installed. Please use the Invoke-Build command from now on instead of build.ps1."
			return $InvokeBuild
		}
	} else {
		Write-Warning "Invoke-Build not found either as a Powershell Module or as an Installed NuGet module."
		if ($Quiet) {
			return $true
		}
	}
}

#region Main
Write-Host -fore green "Detected Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

if (-not $FindInvokeBuild) {
	. $PSScriptRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
	Import-PowerCDModuleFast InvokeBuild
}
Invoke-Expression "Invoke-Build $($args -join ' ')"
exit $LastExitCode
#endRegion Main