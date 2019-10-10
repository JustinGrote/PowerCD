echo "Before"

function GenerateAzDevopsMatrix {
    $os = @(
        'windows-latest'
        'vs2017-win2016'
        'ubuntu-latest'
        'macOS-latest'
    )

    $psversion = @(
        'pwsh'
        'powershell'
    )

    $exclude = 'ubuntu-latest-powershell','macOS-latest-powershell'

    $entries = @{}
    foreach ($osItem in $os) {
        foreach ($psverItem in $psversion) {
            $entries."$osItem-$psverItem" = @{os=$osItem;psversion=$psverItem}
        }
    }

    $exclude.foreach{
        $entries.Remove($PSItem)
    }

    $entries.keys | sort | foreach {
        "      $PSItem`:"
        "        os: $($entries[$PSItem].os)"
        "        psversion: $($entries[$PSItem].psversion)"
    }

}

 #requires -Version 2.0
<#
    .NOTES
    ===========================================================================
     Filename              : Merge-Hashtables.ps1
     Created on            : 2014-09-04
     Created by            : Frank Peter Schultze
    ===========================================================================

    .SYNOPSIS
        Create a single hashtable from two hashtables where the second given
        hashtable will override.

    .DESCRIPTION
        Create a single hashtable from two hashtables. In case of duplicate keys
        the function the second hashtable's key values "win". Merge-Hashtables
        supports nested hashtables.

    .EXAMPLE
        $configData = Merge-Hashtables -First $defaultData -Second $overrideData

    .INPUTS
        None

    .OUTPUTS
        System.Collections.Hashtable
#>
function Merge-Hashtables
{
    [CmdletBinding()]
    Param
    (
        #Identifies the first hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $First
    ,
        #Identifies the second hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $Second
    )

    function Set-Keys ($First, $Second)
    {
        @($First.Keys) | Where-Object {
            $Second.ContainsKey($_)
        } | ForEach-Object {
            if (($First.$_ -is [Hashtable]) -and ($Second.$_ -is [Hashtable]))
            {
                Set-Keys -First $First.$_ -Second $Second.$_
            }
            else
            {
                $First.Remove($_)
                $First.Add($_, $Second.$_)
            }
        }
    }

    function Add-Keys ($First, $Second)
    {
        @($Second.Keys) | ForEach-Object {
            if ($First.ContainsKey($_))
            {
                if (($Second.$_ -is [Hashtable]) -and ($First.$_ -is [Hashtable]))
                {
                    Add-Keys -First $First.$_ -Second $Second.$_
                }
            }
            else
            {
                $First.Add($_, $Second.$_)
            }
        }
    }

    # Do not touch the original hashtables
    $firstClone  = $First.Clone()
    $secondClone = $Second.Clone()

    # Bring modified keys from secondClone to firstClone
    Set-Keys -First $firstClone -Second $secondClone

    # Bring additional keys from secondClone to firstClone
    Add-Keys -First $firstClone -Second $secondClone

    # return firstClone
    $firstClone
}
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
        $DestinationDirectory = New-Item -ItemType Directory -Path $Destination -ErrorAction Stop -Verbose
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
            Copy-Item -Path $PSItem -Destination $DestinationPath -Verbose
        }
    }

    #Output the modified Root Module
    $SourceRootModule > (join-path $DestinationDirectory $SourceManifest.RootModule)

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
} #requires -module BuildHelpers
<#
.SYNOPSIS
Builds a settings object (nested hashtable).
.DESCRIPTION
This builds a layered settings object that starts with intelligent defaults, and then imports the user preferences from a build.psd1 file.
Once built the object is saved as a readonly Hashtable, which allows changing the values but not the structure, for safety, so the user can also edit the values directly
.NOTES
#TODO: Support YAML and JSON input, maybe switch to Microsoft.Extensions.Configuration
#>

function Get-PowerCDSetting {
    [CmdletBinding()]
    param(
        #Path to the initial PowerCDSettings File.
        $Path
    )

    function New-SortedDictionary ([String]$ValueType='Object') {
        new-object "Collections.Generic.SortedDictionary[String,$ValueType]" -ArgumentList ([StringComparer]::OrdinalIgnoreCase)
    }

    #Initialize the Settings Builder as a case-insensitive autosorting hashtable
    #TODO: Consider doing this as a class to enforce type safety
    $PowerCDSettings = New-SortedDictionary

    #Import the Build Environment
    $PowerCDSettings.Environment = New-SortedDictionary 'String'
    (BuildHelpers\Get-BuildEnvironment).psobject.properties | Sort-Object name | Foreach-Object {
        $PowerCDSettings.Environment[$PSItem.Name] = [String]$PSItem.Value
    }



    #TODO: Pull in environment variables

    return $PowerCDSettings
} function Get-PowerCDVersion {
    [CmdletBinding()]

    #TODO: Move this to dedicated dependency handler
    $ModulePath = Import-PowerCDModuleFast GitVersion.CommandLine -Package
    $GitVersionEXE = [IO.Path]::Combine($ModulePath,'tools','GitVersion.exe')

    #If this commit has a tag on it, temporarily remove it so GitVersion calculates properly
    #Fixes a bug with GitVersion where tagged commits don't increment on non-master builds.
    $currentTag = git tag --points-at HEAD

    if ($currentTag) {
        write-build DarkYellow "Task $($task.name) - Git Tag $currentTag detected. Temporarily removing for GitVersion calculation."
        git tag -d $currentTag
    }

    #Strip prerelease tags, GitVersion can't handle them with Mainline deployment with version 4.0
    #TODO: Restore these for local repositories, otherwise they just come down with git pulls
    #FIXME: Remove this because
    #git tag --list v*-* | % {git tag -d $PSItem}

    try {
        #Calculate the GitVersion
        write-verbose "Executing GitVersion to determine version info"

        if ($isLinux -and -not $isAppveyor) {
            #TODO: Find a more platform-independent way of changing GitVersion executable permissions (Mono.Posix library maybe?)
            #https://www.nuget.org/packages/Mono.Posix.NETStandard/1.0.0
            chmod +x $GitVersionEXE
        }

        $GitVersionOutput = & $GitVersionEXE /nofetch
        if (-not $GitVersionOutput) {throw "GitVersion returned no output. Are you sure it ran successfully?"}

        #Since GitVersion doesn't return error exit codes, we look for error text in the output
        if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe in $buildRoot"}
        $SCRIPT:GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop

        if ($PCDSetting.Debug) {
            & $gitversionexe /nofetch /diag | write-debug
        }

        $GitVersionInfo | format-list | out-string | write-verbose
        [String]$PCDSetting.VersionLabel = $GitVersionInfo.NuGetVersionV2
        [Version]$PCDSetting.Version      = $GitVersionInfo.MajorMinorPatch
        [String]$PCDSetting.PreRelease   = $GitVersionInfo.NuGetPreReleaseTagV2

        if ($PCDSetting.Environment.BuildOutput) {
            $PCDSetting.BuildModuleOutput = [io.path]::Combine($PCDSetting.Environment.BuildOutput,$PCDSetting.Environment.ProjectName,$PCDSetting.Version)
        }
    } catch {
        write-error "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is below...`r`n$GitVersionOutput"
    } finally {
        #Restore the tag if it was present
        #TODO: Evaluate if this is still necessary
        # if ($currentTag) {
        #     write-build DarkYellow "Task $($task.name) - Restoring tag $currentTag."
        #     git tag $currentTag -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        # }
    }

    return $GitVersionOutput

    # #GA release detection
    # if ($BranchName -eq 'master') {
    #     $Script:IsGARelease = $true
    #     $Script:ProjectVersion = $ProjectBuildVersion
    # } else {
    #     #The regex strips all hypens but the first one. This shouldn't be necessary per NuGet spec but Update-ModuleManifest fails on it.
    #     $SCRIPT:ProjectPreReleaseVersion = $GitVersionInfo.nugetversion -replace '(?<=-.*)[-]'
    #     $SCRIPT:ProjectVersion = $ProjectPreReleaseVersion
    #     $SCRIPT:ProjectPreReleaseTag = $SCRIPT:ProjectPreReleaseVersion.split('-')[1]
    # }

    # write-build Green "Task $($task.name)` - Calculated Project Version: $ProjectVersion"

    # #Tag the release if this is a GA build
    # if ($BranchName -match '^(master|releases?[/-])') {
    #     write-build Green "Task $($task.name)` - In Master/Release branch, adding release tag v$ProjectVersion to this build"

    #     $SCRIPT:isTagRelease = $true
    #     if ($BranchName -eq 'master') {
    #         write-build Green "Task $($task.name)` - In Master branch, marking for General Availability publish"
    #         [Switch]$SCRIPT:IsGARelease = $true
    #     }
    # }

    # #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    # $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    # if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    # $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    # write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
} function Import-PowerCDModuleFast ($ModuleName,[Switch]$Package,[Switch]$Force) {
    process {
        #Get a temporary directory
        $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(),'PowerCD',$ModuleName)
        $tempfile = join-path $tempModulePath "$ModuleName.zip"

        if ((Test-Path $tempfile) -and -not $Force) {
            Write-Verbose "$ModuleName already installed as $tempfile"
            if ($Package) {$tempModulePath}
            return
        }

        #This only happens if -Force was specified, so we require confirmation so that the user didn't do something stupid like put ../../.. in the path
        if (Test-Path $tempModulePath) {Remove-Item $tempModulePath -Recurse -Confirm:$true}

        New-Item -ItemType Directory -Path $tempModulePath > $null

        #Fetch and import the module
        $baseURI = 'https://powershellgallery.com/api/v2/package/'
        if ($Package) {
            $baseURI = 'https://www.nuget.org/api/v2/package/'
        }
        $moduleLatestURI = "$baseURI$ModuleName"

        write-verbose "Fetching $ModuleName from $moduleLatestURI"
        (New-Object Net.WebClient).DownloadFile($moduleLatestURI, $tempfile)

        $CurrentProgressPreference = $ProgressPreference
        $GLOBAL:ProgressPreference = 'silentlycontinue'
        Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
        $GLOBAL:ProgressPreference = $CurrentProgressPreference

        $ModuleToImportPath = Join-Path $tempModulePath "$ModuleName.psd1"
        if (-not $Package) {
            write-verbose "Importing $ModuleName from $ModuleToImportPath"
            Import-Module $ModuleToImportPath -force
        } else {
            $tempModulePath
        }
    }
} <#
.SYNOPSIS
Initializes the build environment and detects various aspects of the environment
#>

function Initialize-PowerCD {
    [CmdletBinding()]
    param (
        #Specify this if you don't want initialization to switch to the folder build root
        [Switch]$SkipSetBuildRoot
    )

    try {
        Import-Module BuildHelpers -ErrorAction Stop
    } catch {
        Import-PowerCDModuleFast BuildHelpers -Erroraction Stop
    }

    . $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Script -Option ReadOnly -Force -Value (Get-PowerCDSetting)

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($pcdsetting.environment.buildsystem -and $pcdsetting.environment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = "SilentlyContinue"
    }
}
 #requires -module BuildHelpers

function Invoke-PowerCDClean {
    [CmdletBinding()]
    param (
        $buildProjectPath = $pcdSetting.Environment.ProjectPath,
        $buildOutputPath  = $pcdSetting.Environment.BuildOutput,
        $buildProjectName = $pcdSetting.Environment.ProjectName
    )

    #Taken from Invoke-Build because it does not preserve the command in the scope this function normally runs
    #Copyright (c) Roman Kuzmin
    function Remove-BuildItem([Parameter(Mandatory=1)][string[]]$Path) {
        if ($Path -match '^[.*/\\]*$') {*Die 'Not allowed paths.' 5}
        $v = $PSBoundParameters['Verbose']
        try {
            foreach($_ in $Path) {
                if (Get-Item $_ -Force -ErrorAction 0) {
                    if ($v) {Write-Verbose "remove: removing $_" -Verbose}
                    Remove-Item $_ -Force -Recurse
                }
                elseif ($v) {Write-Verbose "remove: skipping $_" -Verbose}
            }
        }
        catch {
            *Die $_
        }
    }

    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        Remove-BuildItem $buildOutputPath
    }

    New-Item -Type Directory $BuildOutputPath > $null

    #Unmount any modules named the same as our module
    Remove-Module $buildProjectName -erroraction silentlycontinue
}



echo "After"
