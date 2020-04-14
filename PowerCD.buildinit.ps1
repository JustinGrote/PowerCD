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
        $env:PSModulePath = ($env:PSModulePath -split [Path]::PathSeparator | Where-Object {$_ -match 'WindowsPowershell'}) -join [Path]::PathSeparator
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
    if ($version) {$downloadURI += "/$Version"}buc
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
        Remove-Item $itemsToRemove -Recurse

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


#Bootstrap package management in a new process. If you try to do it same-process you can't import it because the DLL from the old version is already loaded
#YOU MUST DO THIS IN A NEW SESSION PRIOR TO RUNNING ANY PACKAGEMANGEMENT OR POWERSHELLGET COMMANDS
#NOTES: Tried using a runspace but install-module would crap out on older PS5.x versions.

# function BootstrapPSGet {
#     $psGetVersionMinimum = '2.2.1'
#     $PowershellGetModules = get-module PowershellGet -listavailable | where version -ge $psGetVersionMinimum
#     if ($PowershellGetModules) {
#         write-verbose "PowershellGet $psGetVersionMinimum found. Skipping bootstrap..."
#         return
#     }

#     write-verbose "PowershellGet $psGetVersionMinimum not detected. Bootstrapping..."
#     Start-Job -Verbose -Name "BootStrapPSGet" {
#         $psGetVersionMinimum = '2.2.1'
#         $progresspreference = 'silentlycontinue'
#         Install-Module PowershellGet -MinimumVersion $psGetVersionMinimum -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
#     } | Receive-Job -Wait -Verbose
#     Remove-Job -Name "BootStrapPSGet"
#     Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop
# }
# BootStrapPSGet

# Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop

#endregion Bootstrap

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
        Import-Module @importModuleParams -ErrorAction Stop
    } catch [IO.FileNotFoundException] {
        #Install from Gallery and try again
        Install-PSGalleryModule -Name $Name -Version $Version -Destination $Destination
        Import-Module @importModuleParams -ErrorAction Stop
    }
}

$PowerCDSourcePath = "$PSScriptRoot/PowerCD/PowerCD.psd1"
$SCRIPT:PowerCDMetaBuild = Test-Path $PowerCDSourcePath
if ($PowerCDMetaBuild) {
    write-verbose "Detected this is a meta-build of PowerCD. Loading the module from source path"
    Get-Module PowerCD | Remove-Module -Force
    Import-Module -Scope Global $PowerCDSourcePath
}

#Get Invoke-Build if not present
if (-not (Get-Command Invoke-Build -ErrorAction SilentlyContinue)) {
    Install-Module -Scope CurrentUser InvokeBuild -Force 4>$null
}



#region EndHelperFunctions