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

function DetectNestedPowershell {
    #Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
    if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
        Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
        $env:PSModulePath = ($env:PSModulePath -split [io.path]::PathSeparator | where {$_ -match 'WindowsPowershell'}) -join [io.path]::PathSeparator
        $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
            Where-Object Version -lt 6.0.0 |
            Sort-Object Version -Descending |
            Select-Object -First 1
        Remove-Module 'Microsoft.Powershell.Utility'
        Import-Module $ModuleToImport -Force
    }
}

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
		#Specify this if you want InvokeBuild to be discovered as a nuget package. Disabled by default due to PackageManagement module dependency
		[Switch]$NugetPackageDetection
	)

	if (-not $SkipPSModuleDetection) {
		Write-Verbose "Detecting InvokeBuild as a Powershell Module..."
		$invokeBuild = (Get-Module InvokeBuild -listavailable -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1) | Where-Object version -ge $MinimumVersion | Foreach-Object modulebase
    }

    #We can't do Get-Command because it will load the module, which will break our bootstrap if we need to update packagemanagement later on. This is a loose alternative (it assumes that the latest is available)
    $GetPackageAvailable = ('Get-Package' -in (gmo packagemanagement -listavailable).exportedcommands.keys)

	if (-not $invokeBuild -and $GetPackageAvailable -and $NugetPackageDetection) {
		Write-Verbose "InvokeBuild not found as a Powershell Module. Checking for NuGet package..."
		$invokeBuild = Get-Package Invoke-Build -MinimumVersion $MinimumVersion -erroraction silentlycontinue | Sort-Object version -descending | Select-Object -first 1 | Foreach-Object source
	}

	if ($InvokeBuild) {
		Write-Verbose "Invoke-Build $MinimumVersion was detected at $InvokeBuild."
		return $invokeBuild
	} else {
		Write-Warning "Invoke-Build not found either as a Powershell Module or as an Installed NuGet module. Bootstrapping..."
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

            if ((Test-Path $tempfile) -and -not $Force) {
                Write-Verbose "$ModuleName already found in $tempModulePath"
            }
            else {
                if (Test-Path $tempModulePath) {
                    Remove-Item $tempfile -Force
                    Remove-Item $tempModulePath -Recurse -Force
                }

                New-Item -ItemType Directory -Path $tempModulePath > $null

                #Fetch and import the module
                [uri]$baseURI = 'https://powershellgallery.com/api/v2/package/'
                if ($Package) {
                    [uri]$baseURI = 'https://www.nuget.org/api/v2/package/'
                }

                [uri]$moduleURI = [uri]::new($baseURI, "$ModuleName/")

                if ($Version) {
                    #Ugly syntax for what is effectively "Join-Path" for URIs
                    $moduleURI = [uri]::new($moduleURI,"$version/")
                }

                Write-Verbose "Fetching $ModuleName from $moduleURI"
                (New-Object Net.WebClient).DownloadFile($moduleURI, $tempfile)

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
DetectNestedPowershell

$InvokeBuildPath = FindInvokeBuild
if (-not $InvokeBuildPath) {
	#Bootstrap it
    Import-ModuleFast InvokeBuild
}

Invoke-Expression "Invoke-Build $($args -join ' ')"

Write-Host -fore green "End Invoke-Build Bootstrap"
#endregion Main