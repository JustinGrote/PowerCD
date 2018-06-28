#requires -version 5
#requires -module BuildHelpers
#Build Script for Powershell Modules
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

param (
    #Skip publishing to various destinations (Appveyor,Github,PowershellGallery,etc.)
    [Switch]$SkipPublish,
    #Force publish step even if we are not in master. If you are following GitFlow or GitHubFlow you should never need to do this.
    [Switch]$ForcePublish,
    #Show detailed environment variables. WARNING: Running this in a CI like appveyor may expose your secrets to the log! Be careful!
    [Switch]$ShowEnvironmentVariables,
    #Powershell modules required for the build process
    [String[]]$BuildHelperModules = @("BuildHelpers","Pester","powershell-yaml","Microsoft.Powershell.Archive","PSScriptAnalyzer"),
    #Which build files/folders should be excluded from packaging
    [String[]]$BuildFilesToExclude = @("Build","Release","Tests",".git*","appveyor.yml","gitversion.yml","*.build.ps1",".vscode",".placeholder"),
    #Where to perform the building of the module. Defaults to "Release" under the project directory. You can specify either a path relative to the project directory, or a literal alternate path.
    [String]$BuildOutputPath,
    #NuGet API Key for Powershell Gallery Publishing. Defaults to environment variable of the same name
    [String]$NuGetAPIKey = $env:NuGetAPIKey,
    #GitHub User for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubUserName = $env:GitHubAPIKey,
    #GitHub API Key for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubAPIKey = $env:GitHubAPIKey
)

#Initialize Build Environment
Enter-Build {
    #TODO: Make bootstrap module loading more flexible and dynamic
    <#
    if (-not (Get-Command "Set-BuildEnvironment" -module BuildHelpers)) {
        $HelpersPath = "$Buildroot\Build\Helpers"
        import-module -force -name "$HelpersPath\BuildHelpers"
    }
    #>

    #Move to the Project Directory if we aren't there already. This should never be necessary, just a sanity check
    Set-Location $buildRoot

    #Set the buildOutputPath to "Release" by default if not otherwise specified
    if (-not $BuildOutputPath) {
        $BuildOutputPath = "Release"
    }

    #Configure some easy to use build environment variables
    Set-BuildEnvironment -BuildOutput $BuildOutputPath -Force
    $BuildProjectPath = join-path $env:BHBuildOutput $env:BHProjectName
    $Timestamp = Get-date -format "yyyyMMdd-HHmmss"

    #If this is a meta-build of PowerCD, include certain additional files that are normally excluded.
    #This is so we can use the same build file for both PowerCD and templates deployed from PowerCD.
    $PowerCDIncludeFiles = @("Build","Tests",".git*","appveyor.yml","gitversion.yml","*.build.ps1",".vscode",".placeholder")
    if ($env:BHProjectName -match 'PowerCD') {
        $BuildFilesToExclude = $BuildFilesToExclude | where {$PowerCDIncludeFiles -notcontains $PSItem}
    }
    #Define the Project Build Path

    Write-Build Green "Build Initialization - Project Build Path: $BuildProjectPath"

    #If the branch name is master-test, run the build like we are in "master"
    if ($env:BHBranchName -eq 'master-test') {
        write-build Magenta "Build Initialization - Detected master-test branch, running as if we were master"
        $SCRIPT:BranchName = "master"
    } else {
        $SCRIPT:BranchName = $env:BHBranchName
    }
    write-build Green "Build Initialization - Current Branch Name: $BranchName"
    $PassThruParams = @{}
    if ( ($VerbosePreference -ne 'SilentlyContinue') -or ($CI -and ($BranchName -ne 'master')) ) {
        write-build Green "Build Initialization - Verbose Build Logging Enabled"
        $SCRIPT:VerbosePreference = "Continue"
        $PassThruParams.Verbose = $true
    }


    $lines = '----------------------------------------------------------------'
    function Write-VerboseHeader ([String]$Message) {
        #Simple function to add lines around a header
        write-verbose ""
        write-verbose $lines
        write-verbose $Message
        write-verbose $lines
    }

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ([Environment]::GetCommandLineArgs() -like '-noni*')) {
        write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        $ProgressPreference = "SilentlyContinue"
    }

    #Register Nuget
    if (!(get-packageprovider "Nuget" -ForceBootstrap -ErrorAction silentlycontinue)) {
        write-verbose "Nuget Provider Not found. Fetching..."
        Install-PackageProvider Nuget -forcebootstrap -scope currentuser @PassThruParams | out-string | write-verbose
        write-verboseheader "Installed Nuget Provider Info"
        Get-PackageProvider Nuget @PassThruParams | format-list | out-string | write-verbose
    }

    #Fix a bug with the Appveyor 2017 image having a broken nuget (points to v3 URL but installed packagemanagement doesn't query v3 correctly)
    if ($ENV:APPVEYOR -and ($ENV:APPVEYOR_BUILD_WORKER_IMAGE -eq 'Visual Studio 2017')) {
        write-verbose "Detected Appveyor VS2017 Image, using v2 Nuget API"
        #Next command will detect this was removed and add this back
        UnRegister-PackageSource -Name nuget.org


        #Add the nuget repository so we can download things like GitVersion
        # TODO: Make this optional code when running interactively
        if (!(Get-PackageSource "nuget.org" -erroraction silentlycontinue)) {
            write-verbose "Registering nuget.org as package source"
            Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted @PassThruParams  | out-string | write-verbose
        }
        else {
            $nugetOrgPackageSource = Set-PackageSource -name 'nuget.org' -Trusted @PassThruParams
            if ($PassThruParams.Verbose) {
                write-verboseheader "Nuget.Org Package Source Info"
                $nugetOrgPackageSource | format-table | out-string | write-verbose
            }
        }
    }


    #Move to the Project Directory if we aren't there already. This should never be necessary, just a sanity check
    Set-Location $buildRoot

    #Force TLS 1.2 for all HTTPS transactions
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    write-verboseheader "Build Environment Prepared! Environment Information:"
    Get-BuildEnvironment | format-list | out-string | write-verbose
    if ($ShowEnvironmentVariables) {
        write-verboseheader "Current Environment Variables"
        get-childitem env: | out-string | write-verbose

        write-verboseheader "Powershell Variables"
        Get-Variable | select-object name, value, visibility | format-table -autosize | out-string | write-verbose
    }
}

task Clean {
    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        remove-item $buildProjectPath -Recurse @PassThruParams
        remove-item $buildOutputPath\PowerCD-TestResults*.xml
    }
    New-Item -Type Directory $BuildProjectPath @PassThruParams | out-null
    #Unmount any modules named the same as our module
    Remove-Module $env:BHProjectName -erroraction silentlycontinue
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$buildRoot/GitVersion.yml"

    #Fetch GitVersion if required
    $GitVersionEXE = (Get-Item "$BuildRoot\Build\Helpers\GitVersion\*\GitVersion.exe" -erroraction silentlycontinue | Select-Object -last 1).fullname
    if (-not (Test-Path -PathType Leaf $GitVersionEXE)) {
        $GitVersionCMDPackageName = "gitversion.commandline"
        $GitVersionCMDPackage = Get-Package $GitVersionCMDPackageName -erroraction SilentlyContinue
        if (!($GitVersionCMDPackage)) {
            write-verbose "Package $GitVersionCMDPackageName Not Found Locally, Installing..."
            write-verboseheader "Nuget.Org Package Source Info for fetching GitVersion"
            Get-PackageSource | Format-Table | out-string | write-verbose

            #Fetch GitVersion
            $GitVersionCMDPackage = Install-Package $GitVersionCMDPackageName -scope currentuser -source 'nuget.org' -force @PassThruParams
        }
        $GitVersionEXE = ((Get-Package $GitVersionCMDPackageName).source | split-path -Parent) + "\tools\GitVersion.exe"
    }

    #Does this project have a module manifest? Use that as the Gitversion starting point (will use this by default unless project is tagged higher)
    #Uses Powershell-YAML module to read/write the GitVersion.yaml config file
    #FIXME: Rewrite this to just use regex, because powershell-yaml sucks and can't deal with nested YAML
    <#
    if (Test-Path $env:BHPSModuleManifest) {
        write-verbose "Fetching Version from Powershell Module Manifest (if present)"
        $ModuleManifestVersion = [Version](Get-Metadata $env:BHPSModuleManifest)
        write-verbose "Getting the version in GitVersion.yml and overriding if necessary"
        if (Test-Path $GitVersionConfig) {
            $GitVersionConfigYAML = [ordered]@{}
            #ConvertFrom-YAML returns as individual key-value hashtables, we need to combine them into a single hashtable
            (Get-Content $GitVersionConfig | ConvertFrom-Yaml) | foreach-object {$GitVersionConfigYAML += $PSItem}
            $GitVersionConfigYAML.'next-version' = $ModuleManifestVersion.ToString()
            $GitVersionConfigYAML | ConvertTo-Yaml | Out-File $GitVersionConfig
        }
        else {
            @{"next-version" = $ModuleManifestVersion.toString()} | ConvertTo-Yaml | Out-File $GitVersionConfig
        }
    }
    #>

    #Calculate the GitVersion
    write-verbose "Executing GitVersion to determine version info"
    $GitVersionOutput = Invoke-BuildExec { &$GitVersionEXE $BuildRoot }

    #Since GitVersion doesn't return error exit codes, we look for error text in the output in the output
    if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe in $buildRoot"}
    try {
        $SCRIPT:GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop
    } catch {
        throw "There was an error when running GitVersion.exe $buildRoot. The output of the command (if any) follows:"
        $GitVersionOutput
    }

    write-verboseheader "GitVersion Results"
    $GitVersionInfo | format-list | out-string | write-verbose

    $SCRIPT:ProjectBuildVersion = [Version]$GitVersionInfo.MajorMinorPatch

    $SCRIPT:ProjectSemVersion = $($GitVersionInfo.fullsemver)

    #Powershell Gallery only accepts SemVer V1 Prerelease tags. This means no periods
    $SCRIPT:ProjectPreReleaseTag = $GitVersionInfo.NuGetVersion.split('-') | Select -last 1

    write-build Green "Task $($task.name)` - Using Project Version:            $ProjectBuildVersion"
    write-build Green "Task $($task.name)` - Using Project Version (Extended): $($GitVersionInfo.fullsemver)"

    #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    write-build Green "Task $($task.name)` - Release Path: $BuildReleasePath"
}

#Copy all powershell module "artifacts" to Build Directory
task CopyFilesToBuildDir {

    #Make sure we are in the project location in case something changed
    Set-Location $buildRoot

    #The file or file paths to copy, excluding the powershell psm1 and psd1 module and manifest files which will be autodetected
    copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $BuildReleasePath @PassThruParams
}

#Update the Metadata of the Module with the latest Version
task UpdateMetadata Version,CopyFilesToBuildDir,{
    # Update-ModuleManifest butchers PrivateData, using update-metadata from BuildHelpers instead.

    # Set the Module Version to the calculated Project Build version. Cannot use update-modulemanifest for this because it will complain the version isn't correct (ironic)
    Update-Metadata -Path $buildReleaseManifest -PropertyName ModuleVersion -Value $ProjectBuildVersion

    # This is needed for proper discovery by get-command and Powershell Gallery
    $moduleFunctionsToExport = (Get-ChildItem "$BuildReleasePath\Public" -Filter *.ps1).basename
    if (-not $moduleFunctionsToExport) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
    } else {
        Update-Metadata -Path $BuildReleaseManifest -PropertyName FunctionsToExport -Value $moduleFunctionsToExport
    }

    # Are we in the master or develop/development branch? Bump the version based on the powershell gallery if so, otherwise add a build tag
    if ($BranchName -match '^(master|dev(elop)?(ment)?)$') {
        write-build Green "Task $($task.name)` - In Master/Develop branch, adding Tag Version $ProjectBuildVersion to this build"
        $Script:ProjectVersion = $ProjectBuildVersion
        if (-not (git tag -l $ProjectBuildVersion)) {
            git tag "v$ProjectBuildVersion"
        } else {
            write-warning "Tag $ProjectBuildVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen."
        }
    } else {
        [switch]$Script:IsPreRelease = $true
        write-build Green "Task $($task.name)` Not in Master/Develop branch, marking this as a feature prelease build"
        $Script:ProjectVersion = $Project
        #Set an email address for tag commit to work if it isn't already present
        if (-not (git config user.email)) {
            git config user.email "buildtag@$env:ComputerName"
            $tempTagGitEmailSet = $true
        }
        try {
            $gitVersionTag = "v$ProjectSemVersion"
            if (-not (git tag -l $gitVersionTag)) {
                exec { git tag "$gitVersionTag" -a -m "Automatic GitVersion Prerelease Tag Generated by Invoke-Build" }
            } else {
                write-warning "Tag $gitVersionTag already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen"
            }
        } finally {
            if ($tempTagGitEmailSet) {
                git config --unset user.email
            }
        }

        #Create an empty file in the root directory of the module for easy identification that its not a valid release.
        "This is a prerelease build and not meant for deployment!" > (Join-Path $BuildReleasePath "PRERELEASE-$ProjectSemVersion")

        #Set the prerelease version in the Manifest File
        Update-Metadata -Path $BuildReleaseManifest -PropertyName PreRelease -value $ProjectPreReleaseTag
    }

    # Add Release Notes from current version
    # TODO: Generate Release Notes from GitHub
    #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ReleaseNotes -Value ("$($env:APPVEYOR_REPO_COMMIT_MESSAGE): $($env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)")
}

#Pester Testing
task Pester {
    #Find the latest module
    try {
        $moduleManifestCandidatePath = join-path (join-path $BuildProjectPath '*') '*.psd1'
        $moduleManifestCandidates = Get-Item $moduleManifestCandidatePath -ErrorAction stop
        $moduleManifestPath = ($moduleManifestCandidates | Select-Object -last 1).fullname
        $moduleDirectory = Split-Path $moduleManifestPath
    } catch {
        throw "Did not detect any module manifests in $BuildProjectPath. Did you run 'Invoke-Build Build' first?"
    }

    write-verboseheader "Starting Pester Tests..."
    write-build Green "Task $($task.name)` -  Testing $moduleDirectory"

    $PesterResultFile = "$env:BHBuildOutput\$env:BHProjectName-TestResults_PS$PSVersion`_$TimeStamp.xml"

    $PesterParams = @{
        Script = @{Path = "Tests"; Parameters = @{ModulePath = (split-path $moduleManifestPath)}}
        OutputFile = $PesterResultFile
        OutputFormat = "NunitXML"
        PassThru = $true
        OutVariable = 'TestResults'
    }

    #If we are in vscode, add the VSCodeMarkers
    if ($host.name -match 'Visual Studio Code') {
        write-verbose "Detected Visual Studio Code, adding test markers"
        $PesterParams.PesterOption = (new-pesteroption -IncludeVSCodeMarker)
    }

    Invoke-Pester @PesterParams | Out-Null

    # In Appveyor?  Upload our test results!
    If ($ENV:APPVEYOR) {
        $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        write-verbose "Detected we are running in AppVeyor"
        write-verbose "Uploading Pester Results to Appveyor: $UploadURL"
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $PesterResultFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
        $SkipPublish = $true
    }
    "`n"
}

task Package Version,{
    $ZipArchivePath = (join-path $env:BHBuildOutput "$env:BHProjectName-$ProjectSemVersion.zip")
    write-build Green "Task $($task.name)` - Writing Finished Module to $ZipArchivePath"
    #Package the Powershell Module
    Compress-Archive -Path $BuildProjectPath -DestinationPath $ZipArchivePath -Force @PassThruParams

    $SCRIPT:ArtifactPaths += $ZipArchivePath
    #If we are in Appveyor, push completed zip to Appveyor Artifact
    if ($env:APPVEYOR) {
        write-build Green "Task $($task.name)` - Detected Appveyor, pushing Powershell Module archive to Artifacts"
        Push-AppveyorArtifact $ZipArchivePath
    }
}

task PreDeploymentChecks {
    #Do not proceed if the most recent Pester test is not passing.
    $CurrentErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Stop"
        $MostRecentPesterTestResult = [xml]((Get-Content -raw (get-item "$env:BHBuildOutput/*-TestResults*.xml" | Sort-Object lastwritetime | Select-Object -last 1)))
        $MostRecentPesterTestResult = $MostRecentPesterTestResult."test-results"
        if (
            $MostRecentPesterTestResult -isnot [System.XML.XMLElement] -or
            $MostRecentPesterTestResult.errors -gt 0 -or
            $MostRecentPesterTestResult.failures -gt 0
        ) {throw "Fail!"}
    } catch {
        throw "Unable to detect a clean passing Pester Test nunit xml file in the $BuildOutput directory. Did you run {Invoke-Build Build,Test} and ensure it passed all tests first?"
    }
    finally {
        $ErrorActionPreference = $CurrentErrorActionPreference
    }

    if (($BranchName -eq 'master') -or $ForcePublish) {
        if (-not (Get-Item $BuildReleasePath/*.psd1 -erroraction silentlycontinue)) {throw "No Powershell Module Found in $BuildReleasePath. Skipping deployment. Did you remember to build it first with {Invoke-Build Build}?"}
    } else {
        write-build Magenta "Task $($task.name)` - We are not in master branch, skipping publish. If you wish to publish anyways such as for testing, run {InvokeBuild Publish -ForcePublish:$true}"
        $script:SkipPublish=$true
    }
}

task PublishGitHubRelease -if (-not $SkipPublish) Package,{
    if ($SkipPublish) {$SkipGitHubRelease = $true}
    #TODO: Add Prerelease Logic when message commit says "!prerelease" or is in a release branch
    if ($AppVeyor -and -not $GitHubAPIKey) {
        write-build DarkYellow "Task $($task.name)` - Couldn't find GitHubAPIKey in the Appveyor secure environment variables. Did you save your Github API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }
    if (-not $env:GitHubAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow "Task $($task.name)` - `$env:GitHubAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"

        $SkipGitHubRelease = $true
    }
    if (-not $env:GitHubUserName) {
        write-build DarkYellow "Task $($task.name)` - `$env:GitHubUserName was not found as an environment variable. Please specify it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }
    if ($SkipGitHubRelease) {
        write-build Magenta "Task $($task.name): Skipping Publish to GitHub Releases"
        continue
    } else {
        #TODO: Add Prerelease Logic when message commit says "!prerelease" or is in a release branch
        #Inspiration from https://www.herebedragons.io/powershell-create-github-release-with-artifact

        #Create the release
        $releaseData = @{
            tag_name = [string]::Format("v{0}", $ProjectBuildVersion);
            target_commitish = "master";
            name = [string]::Format("v{0}", $ProjectBuildVersion);
            body = $env:BHCommitMessage;
            draft = $true;
            prerelease = $true;
        }
        $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($GitHubApiKey + ":x-oauth-basic"))
        $releaseParams = @{
            Uri = "https://api.github.com/repos/$env:gitHubUserName/$env:BHProjectName/releases"
            Method = 'POST'
            Headers = @{
                Authorization = $auth
            }
            ContentType = 'application/json'
            Body = (ConvertTo-Json $releaseData -Compress)
        }

        $result = Invoke-RestMethod @releaseParams -ErrorAction stop

        $uploadUriBase = $result.upload_url -creplace '\{\?name,label\}'  # Strip the , "?name=$artifact" part

        $uploadParams = @{
            Method = 'POST';
                Headers = @{
                    Authorization = $auth;
                }
            ContentType = 'application/zip';
        }
        foreach ($artifactItem in $artifactPaths) {
            $uploadparams.URI = $uploadUriBase + "?name=$(split-path $artifactItem -leaf)"
            $uploadparams.Infile = $artifactItem
            $result = Invoke-RestMethod @uploadParams -erroraction stop
        }
    }
}

task PublishPSGallery -if (-not $SkipPublish) {
    if ($SkipPublish) {[switch]$SkipPSGallery = $true}
    if ($AppVeyor -and -not $NuGetAPIKey) {
        write-build DarkYellow "Couldn't find NuGetAPIKey in the Appveyor secure environment variables. Did you save your NuGet/Powershell Gallery API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://www.appveyor.com/docs/build-configuration/"
        $SkipPSGallery = $true
    }
    if (-not $NuGetAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow '$env:NuGetAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build publish -NuGetAPIKey "MyAPIKeyString"}. Have you registered for a Powershell Gallery API key yet? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item'
        $SkipPSGallery = $true
    }

    if ($SkipPSGallery) {
        Write-Build Magenta "Task $($task.name)` - Skipping Powershell Gallery Publish"
        continue
    } else {
        $publishParams = @{
                Path = $BuildReleasePath
                NuGetApiKey = $NuGetAPIKey
                Repository = 'PSGallery'
                Force = $true
                ErrorAction = 'Stop'
                Confirm = $false
        }
        Publish-Module @publishParams @PassThruParams
    }
}

### SuperTasks
# These are the only supported items to run directly from Invoke-Build
task Build Clean,Version,CopyFilesToBuildDir,UpdateMetadata
task Test Pester
task Publish Version,PreDeploymentChecks,Package,PublishGitHubRelease,PublishPSGallery

#Default Task - Build, Test with Pester, publish
task . Clean,Build,Test,Publish