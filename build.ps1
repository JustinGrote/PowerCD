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
		#Specify this if you know it isn't present as a nuget package and want to save some detection time
		[Switch]$SkipNugetPackageDetection,
		#Specify this if you just want a simple true/false result
		[Switch]$Quiet
	)

	if (-not $SkipPSModuleDetection) {
		Write-Verbose "Detecting InvokeBuild as a Powershell Module..."
		$invokeBuild = (Get-Module InvokeBuild -listavailable -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1) | Where-Object version -ge $MinimumVersion | Foreach-Object modulebase
	}

	if (-not $invokeBuild -and (Get-Command Get-Package -erroraction silentlycontinue)) {
		Write-Verbose "InvokeBuild not found as a Powershell Module. Checking for NuGet package..."
		$invokeBuild = Get-Package Invoke-Build -MinimumVersion $MinimumVersion -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1 | Foreach-Object source
	}

	if ($InvokeBuild) {
		if ($Quiet) {
			return $true
		} else {
			Write-Verbose "Invoke-Build $MinimumVersion was detected at $InvokeBuild."
			$invokeBuild
		}
	} else {
		Write-Warning "Invoke-Build not found either as a Powershell Module or as an Installed NuGet module."
		if ($Quiet) {
			return $false
		}
	}
}

#region Main
Write-Host -fore green "Detected Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"


$InvokeBuildPath = FindInvokeBuild
if (-not $InvokeBuildPath) {
	#Bootstrap it
	$InvokeBuildModule = Install-Module -Name InvokeBuild -MinimumVersion $MinimumVersion -scope currentuser -verbose -Force
	Import-Module -Name $InvokeBuildModule.Name -MinimumVersion $MinimumVersion -Force
}

Invoke-Expression "Invoke-Build $($args -join ' ')"
