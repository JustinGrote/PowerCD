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
        #By default, the build will consolidate all relevant module files into a single .psm1 file. This enables the module to load faster. Specify this if you want to instead copy the files as-is
        [Switch]$NoCompile,
        #If you chose compile, specify this for the region block in your .psm1 file to replace with the compiled code. If not specified, it will just append to the end of the file. Defaults to 'SourceInit' for #region SourceInit
        [String]$SourceRegionName = 'SourceInit',
        #Files that are considered for inclusion to the 'compiled' module. This by default includes .ps1 files only. Uses Filesystem Filter syntax
        [String[]]$PSFileInclude = '*.ps1',
        #Files that are considered for inclusion to the 'compiled' module. This excludes any files that have two periods before ps1 (e.g. .build.ps1, .tests.ps1). Uses Filesystem Filter syntax
        [String[]]$PSFileExclude = '*.*.ps1'
    )

    $SourceModuleDir = Split-Path $PSModuleManifest

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

    #TODO: Replace when dropping support for Powershell 5.1
    #PS6+ Preferred Method, doesn't work on 5.1 Windows Server
    #$SourceManifest = Import-PowershellDataFile $PSModuleManifest
    $SourceManifest = Import-LocalizedData -FileName (Split-Path $PSModuleManifest -Leaf) -BaseDirectory (Split-Path $PSModuleManifest)

    #TODO: Allow .psm1 to be blank and generate it on-the-fly
    if (-not $SourceManifest.RootModule) {throw "The source manifest at $PSModuleManifest does not have a RootModule specified. This is required to build the module."}

    $SourceRootModulePath = Join-Path $SourceModuleDir $sourceManifest.RootModule
    $SourceRootModule = Get-Content -Raw $SourceRootModulePath

    $pcdSetting.ModuleManifest = $SourceManifest

    #Cannot use Copy-Item Directly because the filtering isn't advanced enough (can't exclude)
    $SourceFiles = Get-ChildItem -Path $SourceModuleDir -Include $PSFileInclude -Exclude $PSFileExclude -File -Recurse
    if (-not $NoCompile) {
        #TODO: Apply ordering if important (e.g. classes)
        $CombinedSourceFiles = Get-Content -Raw $SourceFiles

        #If a SourceInit region was set, inject the files there, otherwise just append to the end.
        $sourceRegionRegex = "(?s)#region $SourceRegionName.+#endregion $SourceRegionName"
        if ($SourceRootModule -match $sourceRegionRegex) {
            #Need to escape the $ in the replacement string
            $RegexEscapedCombinedSourceFiles = [String]$CombinedSourceFiles.replace('$','$$')
            $SourceRootModule = $SourceRootModule -replace $sourceRegionRegex,$RegexEscapedCombinedSourceFiles
        } else {
            $SourceRootModule += [Environment]::NewLine() + $CombinedSourceFiles
        }
    } else {
        #TODO: Track all files in the source directory to ensure none get missed on the second step
        $SourceFiles | Foreach-Object {
            #Powershell 6+ Preferred way.
            #TODO: Enable when dropping support for building on 5.x
            #$RelativePath = [io.path]::GetRelativePath($SourceModuleDir,$PSItem.fullname)

            #Powershell 5.x compatible "Ugly" Regex method
            $RelativePath = $PSItem.FullName -replace [Regex]::Escape($SourceModuleDir),''

            #Copy-Item doesn't automatically create directory structures when copying files vs. directories
            $DestinationPath = Join-Path $DestinationDirectory $RelativePath
            $DestinationDir = Split-Path $DestinationPath
            if (-not (Test-Path $DestinationDir)) {New-Item -ItemType Directory $DestinationDir -verbose > $null}
            Copy-Item -Path $PSItem -Destination $DestinationPath
        }
    }

    #Output the modified Root Module
    $SourceRootModule | Out-File -FilePath (join-path $DestinationDirectory $SourceManifest.RootModule)

    #Output the current Module Manifest
    $SourceManifest | Out-File -FilePath (join-path $DestinationDirectory (Split-Path -Leaf $SourceManifest))

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