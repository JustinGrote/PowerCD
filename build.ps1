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
		[Switch]$SkipNugetPackageDetection
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
		Write-Verbose "Invoke-Build $MinimumVersion was detected at $InvokeBuild."
		return $invokeBuild
	} else {
		Write-Warning "Invoke-Build not found either as a Powershell Module or as an Installed NuGet module."
		return $false
	}
}

function Import-ModuleFast {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String[]]$ModuleName,
        [String]$Version,
        [Switch]$Package,
        [Switch]$Force
    )
    process {
        foreach ($ModuleName in $ModuleName) {

            #Get a temporary directory
            $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(), 'PowerCD', $ModuleName)
            $ModuleManifestPath = Join-Path $tempModulePath "$ModuleName.psd1"
            $tempfile = join-path $tempModulePath "$ModuleName.zip"

            if ((Test-Path $tempModulePath) -and -not $Force) {
                Write-Verbose "$ModuleName already found in $tempModulePath"
            }
            else {
                if (Test-Path $tempModulePath) {
                    Remove-Item $tempfile -Force
                    Remove-Item $tempModulePath -Recurse -Force
                }

                New-Item -ItemType Directory -Path $tempModulePath > $null

                #Fetch and import the module
                $baseURI = 'https://powershellgallery.com/api/v2/package/'
                if ($Package) {
                    $baseURI = 'https://www.nuget.org/api/v2/package/'
                }

                if ($Version) {
                    #Ugly syntax for what is effectively "Join-Path" for URIs
                    [uri]::new([uri]$baseURI, $version)
                }
                $moduleLatestURI = "$baseURI$ModuleName"

                write-verbose "Fetching $ModuleName from $moduleLatestURI"
                (New-Object Net.WebClient).DownloadFile($moduleLatestURI, $tempfile)

                $CurrentProgressPreference = $ProgressPreference
                $GLOBAL:ProgressPreference = 'silentlycontinue'
                Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
                $GLOBAL:ProgressPreference = $CurrentProgressPreference
            }

            if (-not $Package) {
                write-verbose "Importing $ModuleName from $ModuleManifestPath"
                Import-Module $ModuleManifestPath -force
            }
            else {
                $tempModulePath
            }
        }
    }
}

#region Main
Write-Host -fore green "Detected Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

$InvokeBuildPath = FindInvokeBuild
if (-not $InvokeBuildPath) {
	#Bootstrap it
	Import-ModuleFast InvokeBuild
}

Invoke-Expression "Invoke-Build $($args -join ' ')"
