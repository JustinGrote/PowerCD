#requires -version 5.1
using namespace System.IO

#This bootstraps the invoke-build environment for PowerCD
param (
    #Specify the version of PowerCD to use. By default it will use the latest available either on this system or on Powershell Gallery
    [Version]$PowerCDVersion
)
$ErrorActionPreference = 'Stop'

Write-Host -fore cyan "Task PowerCD.Bootstrap"
$bootstrapTimer = [Diagnostics.Stopwatch]::StartNew()
@("$PSSCRIPTROOT/PowerCD/PowerCD.psd1","./PowerCD/PowerCD.psd1").foreach{
    if (-not $GLOBAL:PowerCDMetaBuild -and (Test-Path $PSItem)) {
        Write-Verbose "PowerCD: Detected meta-build. Loading the module from source path"
        $GLOBAL:PowerCDMetaBuild = $PSItem
    }
}
if ($GLOBAL:PowerCDMetaBuild) {
    Get-Module 'PowerCD' | Remove-Module -Force
    Import-Module -Global -Name $GLOBAL:PowerCDMetaBuild -Force
} else {
    $candidateModules = Get-Module -Name PowerCD -ListAvailable
    if ($PowerCDVersion) {
        if ($PowerCDVersion -in $candidateModules.Version) {
            Import-Module -Name 'PowerCD' -RequiredVersion $PowerCDVersion
        }
    } else {
        Import-Module -Name 'PowerCD'
    }
}

#Install the Module if not found
if (-not (Get-Module -Name 'PowerCD')) {
    Write-Verbose "PowerCD: Module not installed locally. Bootstrapping..."
    $InstallModuleParams = @{
        Name = 'PowerCD'
        Scope = 'CurrentUser'
    }
    if ($PowerCDVersion) {$InstallModuleParams.RequiredVersion = $PowerCDVersion}
    Install-Module @InstallModuleParams -PassThru | Import-Module
}

Write-Host -fore cyan "Done PowerCD.Bootstrap $([string]$bootstrapTimer.elapsed)"

# function DetectNestedPowershell {
#     #Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
#     if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
#         Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
#         $env:PSModulePath = ($env:PSModulePath -split [Path]::PathSeparator | Where-Object {$_ -match 'WindowsPowershell'}) -join [Path]::PathSeparator
#         $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
#             Where-Object Version -lt 6.0.0 |
#             Sort-Object Version -Descending |
#             Select-Object -First 1
#         Remove-Module 'Microsoft.Powershell.Utility'
#         Import-Module $ModuleToImport -Force 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose
#     }
# }

#region HelperFunctions
# function Install-PSGalleryModule {
#     <#
#     .SYNOPSIS
#     Downloads a module from the Powershell Gallery using direct APIs. This is primarily used to bootstrap
#     #>

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)][String]$Name,
#         [Parameter(Mandatory)][String]$Destination,
#         [String]$Version
#     )
#     if (-not (Test-Path $Destination)) {throw "Destination $Destination doesn't exist. Please specify a powershell modules directory"}
#     $downloadURI = "https://www.powershellgallery.com/api/v2/package/$Name"
#     if ($version) {$downloadURI += "/$Version"}buc
#     try {
#         $ErrorActionPreference = 'Stop'
#         $tempZipName = "mybootstrappedPSGalleryModule.zip"
#         $tempDirPath = Join-Path ([io.path]::GetTempPath()) "$Name-$(get-random)"
#         $tempDir = New-Item -ItemType Directory -Path $tempDirPath
#         $tempFilePath = Join-Path $tempDir $tempZipName
#         [void][net.webclient]::new().DownloadFile($downloadURI,$tempFilePath)
#         [void][System.IO.Compression.ZipFile]::ExtractToDirectory($tempFilePath, $tempDir, $true)
#         $moduleManifest = Get-Content -raw (Join-Path $tempDirPath "$Name.psd1")
#         $modulePathVersion = if ($moduleManifest -match "ModuleVersion = '([\.\d]+)'") {$matches[1]} else {throw "Could not read Moduleversion from the module manifest"}
#         $itemsToRemove = @($tempZipName,'_rels','package','`[Content_Types`].xml','*.nuspec').foreach{
#             Join-Path $tempdir $PSItem
#         }
#         Remove-Item $itemsToRemove -Recurse

#         $destinationModulePath = Join-Path $destination $Name
#         $destinationPath = Join-Path $destinationModulePath $modulePathVersion
#         if (-not (Test-Path $destinationModulePath)) {$null = New-Item -ItemType Directory $destinationModulePath}
#         if (Test-Path $destinationPath) {Remove-Item $destinationPath -force -recurse}
#         $null = Move-Item $tempdir -Destination $destinationPath

#         Set-Location -path ([io.path]::Combine($Destination, $Name, $modulePathVersion))
#         #([IO.Path]::Combine($Destination, $Name, $modulePathVersion), $true)
#     } catch {throw $PSItem} finally {
#         #Cleanup
#         if (Test-Path $tempdir) {Remove-Item -Recurse -Force $tempdir}
#     }
# }

Enter-Build {
    Initialize-PowerCD
}

. PowerCD.Tasks
