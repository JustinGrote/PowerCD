#This bootstraps the invoke-build environment for PowerCD
param (
    #Specify the version of PowerCD to use. By default it will use the latest available either on this system or on Powershell Gallery
    [String]$PowerCDVersion,
    #Where bootstrapped modules are saved
    [IO.DirectoryInfo]$BootstrapModulePath
)

#region HelperFunctions
function Install-PSGalleryModule {
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
    Get-Module PowerCD | Remove-Module
    Import-Module -Scope Global $PowerCDSourcePath
} else {
    $bootstrapModuleParams = @{Name='PowerCD'}
    if ($PowerCDVersion) { $bootstrapModuleParams.RequiredVersion = $PowerCDVersion}
    BootstrapModule @bootstrapModuleParams
}
#region EndHelperFunctions