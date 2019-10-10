<#
.SYNOPSIS
This function prepares a powershell module from a source powershell` module directory
.DESCRIPTION
This function can also optionally "compile" the module, which is place all relevant powershell code in a single .psm1 file. This improves module load performance.
If you choose to compile, place any script lines you use to dot-source the other files in your .psm1 file into a #region SourceInit region block, and this function will replace it with the "compiled" scriptblock
#>
function Build-PowerCDModule {
    [CmdletBinding()]
    param (
        #Path to the Powershell Module Manifest representing the file you wish to compile
        $PSModuleManifest = $pcdSetting.Environment.PSModuleManifest,
        #Path to the build destination. This should be non-existent or deleted by Clean prior
        $Destination = $pcdSetting.BuildModuleOutput,
        #By Default this command expects a nonexistent destination, specify this to allow for a "Dirty" copy
        [Switch]$Force,
        #If specified, will consolidate all relevant module files into a single .psm1 file. This enables the module to load faster.
        [Switch]$Compile,
        #If you chose compile, specify this for the region block in your .psm1 file to replace with the compiled code. If not specified, it will just append to the end of the file. Defaults to 'SourceInit' for #region SourceInit
        [String]$SourceRegionName = 'SourceInit'
    )

    #Verify a clean build folder
    try {
        $DestinationDirectory = New-Item -ItemType Directory -Path $Destination -ErrorAction Stop
    } catch [IO.IOException] {
        if ($PSItem.exception.message -match 'already exists\.$') {
            throw "Folder $Destination already exists. Make sure that you cleaned your Build Output directory. To override this behavior, specify -Force"
        } else {
            throw $PSItem
        }
    }

    #TODO: Use this one command and sort out the items later
    #$FilesToCopy = Get-ChildItem -Path $PSModuleManifestDirectory -Filter '*.ps*1' -Exclude '*.tests.ps1' -Recurse

    $SourceManifest = Import-Metadata $PSModuleManifest

    #TODO: Allow .psm1 to be blank and generate it on-the-fly
    if (-not $SourceManifest.RootModule) {throw "The source manifest at $PSModuleManifest does not have a RootModule specified. This is required to build the module."}

    $SourceModule = Get-Content -Raw (Join-Path (Split-Path $PSModuleManifest) $sourceManifest.RootModule)


    $SourceModule > (join-path $Destination $SourceManifest.RootModule)

    #Copy-Module PowershellBuild
<#
    #Detect the .psm1 file and copy all files to the root directory, excluding build files unless this is PowerCD
    if ($PSModuleManifestDirectory -eq $buildRoot) {
        #TODO: Root-folder level module with buildFilesToExclude
        copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $BuildReleasePath @PassThruParams

        throw "Placing module files in the root project folder is current not supported by this script. Please put them in a subfolder with the name of your module"
    } else {
    }
#>
}