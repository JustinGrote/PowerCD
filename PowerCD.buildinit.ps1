#requires -version 5.1
using namespace System.IO

#This bootstraps the invoke-build environment for PowerCD
param (
    #Specify the version of PowerCD to use. By default it will use the latest available either on this system or on Powershell Gallery
    [String]$PowerCDVersion,
    #Where bootstrapped modules are saved
    [IO.DirectoryInfo]$BootstrapModulePath
)
$ErrorActionPreference = 'Stop'
if ($PowerCDBuildInit) {return}

Write-Host -fore cyan "Task PowerCD.Bootstrap"
$bootstrapTimer = [Diagnostics.Stopwatch]::StartNew()

function DetectNestedPowershell {
    #Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
    if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
        Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
        $env:PSModulePath = ($env:PSModulePath -split [io.path]::PathSeparator | Where-Object {$_ -match 'WindowsPowershell'}) -join [io.path]::PathSeparator
        $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
            Where-Object Version -lt 6.0.0 |
            Sort-Object Version -Descending |
            Select-Object -First 1
        Remove-Module 'Microsoft.Powershell.Utility'
        Import-Module $ModuleToImport -Force 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose
    }
}

#region HelperFunctions
function Install-PSGalleryModule {
<#
.SYNOPSIS
Downloads a module from the Powershell Gallery using direct APIs. This is primarily used to bootstrap
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$Name,
        [Parameter(Mandatory)][String]$Destination,
        [String]$Version
    )

    if (-not (Test-Path $Destination)) {throw "Destination $Destination doesn't exist. Please specify a powershell modules directory"}
    $downloadURI = "https://www.powershellgallery.com/api/v2/package/$Name"
    if ($version) {$downloadURI += "/$Version"}
    try {
        $ErrorActionPreference = 'Stop'
        $tempZipName = "mybootstrappedPSGalleryModule.zip"
        $tempDirPath = Join-Path ([io.path]::GetTempPath()) "$Name-$(get-random)"
        $tempDir = New-Item -ItemType Directory -Path $tempDirPath
        $tempFilePath = Join-Path $tempDir $tempZipName
        [void][net.webclient]::new().DownloadFile($downloadURI,$tempFilePath)
        [void][System.IO.Compression.ZipFile]::ExtractToDirectory($tempFilePath, $tempDir, $true)
        $moduleManifest = Get-Content -raw (Join-Path $tempDirPath "$Name.psd1")
        $modulePathVersion = if ($moduleManifest -match "ModuleVersion = '([\.\d]+)'") {$matches[1]} else {throw "Could not read Moduleversion from the module manifest"}
        $itemsToRemove = @($tempZipName,'_rels','package','`[Content_Types`].xml','*.nuspec').foreach{
            Join-Path $tempdir $PSItem
        }
        $itemsToRemove.foreach{
            $verbosepreference = 'continue'
            Remove-Item $PSItem -Recurse -Force -Confirm:$false -Verbose
        }

        $destinationModulePath = Join-Path $destination $Name
        $destinationPath = Join-Path $destinationModulePath $modulePathVersion
        if (-not (Test-Path $destinationModulePath)) {$null = New-Item -ItemType Directory $destinationModulePath}
        if (Test-Path $destinationPath) {Remove-Item $destinationPath -force -recurse}
        $null = Move-Item $tempdir -Destination $destinationPath

        Set-Location -path ([io.path]::Combine($Destination, $Name, $modulePathVersion))
        #([IO.Path]::Combine($Destination, $Name, $modulePathVersion), $true)
    } catch {throw $PSItem} finally {
        #Cleanup
        if (Test-Path $tempdir) {Remove-Item -Recurse -Force $tempdir}
    }
}

function BootStrapModule {
    #Tries to load a module and dynamically downloads it from the Powershell Gallery if not available.
    [CmdletBinding()]
    param(
        [String]$Name,
        [Alias('RequiredVersion')][String]$Version,
        $Destination=([IO.Path]::Combine([System.Environment]::GetFolderPath('LocalApplicationData'),'PowerCD',$PSScriptRoot.Parent.Name))
    )

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory $Destination -ErrorAction Stop
    }

    $importModuleParams = @{
        Name = $Name
    }
    if ($Version) { $importModuleParams.RequiredVersion = $Version.split('-')[0] }

    #Attempt to load the module
    try {
        $psModulePaths = [Collections.Generic.List[String]]$env:PSModulePath.split([io.path]::PathSeparator)
        if ($destination -notin $psModulePaths) {
            write-verbose "Adding Module Bootstrap $destination to PSModulePath"
            $psmodulePaths.insert(0,$destination)
            $env:PSModulePath = $psModulePaths -join [io.path]::PathSeparator
        }

        Import-Module @importModuleParams -ErrorAction Stop 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose
    } catch [IO.FileNotFoundException] {
        #Install from Gallery and try again
        Install-PSGalleryModule -Name $Name -Version $Version -Destination $Destination

        Import-Module @importModuleParams -ErrorAction Stop 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose
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
    $GetPackageAvailable = ('Get-Package' -in (Get-Module -Name PackageManagement -ListAvailable).exportedcommands.keys)

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

#region Main
Write-Host -fore green "Detected Powershell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
DetectNestedPowershell

$InvokeBuildPath = FindInvokeBuild
if (-not $InvokeBuildPath) {
    BootStrapModule InvokeBuild
}

$PowerCDSourcePath = "$PSScriptRoot/PowerCD/PowerCD.psd1"
$SCRIPT:PowerCDMetaBuild = Test-Path $PowerCDSourcePath
if ($PowerCDMetaBuild) {
    write-verbose "Detected this is a meta-build of PowerCD. Loading the module from source path"
    Get-Module PowerCD | Remove-Module 4>$null
    Import-Module -Name $PowerCDSourcePath -WarningAction SilentlyContinue -Scope Global 4>&1 | Where-Object {$_ -match '^Loading Module.*psm1.+\.$'} | Write-Verbose
} else {
    $bootstrapModuleParams = @{Name='PowerCD'}
    if ($PowerCDVersion) { $bootstrapModuleParams.RequiredVersion = $PowerCDVersion}
    BootstrapModule @bootstrapModuleParams
}

Write-Host -fore cyan "Done PowerCD.Bootstrap $($bootstrapTimer.elapsed)"

#endregion Main