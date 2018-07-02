#requires -version 5
#requires -module BuildHelpers
#Build Script for Powershell Modules
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

param (
    #Skip publishing to various destinations (Appveyor,Github,PowershellGallery,etc.)
    [Switch]$SkipPublish,
    #Force publish step even if we are not in master or release. If you are following GitFlow or GitHubFlow you should never need to do this.
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
    [String]$GitHubUserName = $env:GitHubUserName,
    #GitHub API Key for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubAPIKey = $env:GitHubAPIKey,
    #Setting this option will only publish to Github as "draft" (hidden) releases for both GA and prerelease, that you then must approve to show to the world.
    [Switch]$GitHubPublishAsDraft
)

#region HelperFunctions
$lines = '----------------------------------------------------------------'
#endregion HelperFunctions



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

    #If this is a meta-build of PowerCD, include certain additional files that are normally excluded.
    #This is so we can use the same build file for both PowerCD and templates deployed from PowerCD.
    $PowerCDIncludeFiles = @("Build","Tests",".git*","appveyor.yml","gitversion.yml","*.build.ps1",".vscode",".placeholder")
    if ($env:BHProjectName -match 'PowerCD') {
        $BuildFilesToExclude = $BuildFilesToExclude | Where-Object {$PowerCDIncludeFiles -notcontains $PSItem}
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
    #Fetch GitVersion if required
    $GitVersionEXE = (Get-Item "$BuildRoot\Build\Helpers\GitVersion\*\GitVersion.exe" -erroraction continue | Select-Object -last 1).fullname
    if (-not (Test-Path -PathType Leaf $GitVersionEXE)) {
        throw "Path to Gitversion ($GitVersionEXE) is not valid or points to a folder"
        <# This is temporarily disabled as we need to use the beta gitversion for Mainline Deployment. Will be re-enabled when latest v4 is available on nuget.
            #TODO: Re-enable once Gitversion v4 stable is available
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
        #>
    }

    #Calculate the GitVersion
    write-verbose "Executing GitVersion to determine version info"
    $GitVersionOutput = &$GitVersionEXE $BuildRoot

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
    $SCRIPT:ProjectSemVersion = $GitVersionInfo.fullsemver

    #GA release detection
    if ($BranchName -eq 'master') {
        $Script:IsGARelease = $true
        $Script:ProjectVersion = $ProjectBuildVersion
    } else {
        $SCRIPT:ProjectPreReleaseVersion = $GitVersionInfo.nugetversion
        $SCRIPT:ProjectPreReleaseTag = $ProjectPreReleaseVersion.split('-') | Select-Object -last 1
        $Script:ProjectVersion = $ProjectPreReleaseVersion
    }

    write-build Green "Task $($task.name)` - Calculated Project Version: $ProjectVersion"

    #Tag the release if this is a GA build
    if ($BranchName -match '^(master|releases?[/-])') {
        write-build Green "Task $($task.name)` - In Master/Release branch, adding release tag v$ProjectVersion to this build"
        $SCRIPT:isTagRelease = $true
        if ($BranchName -eq 'master') {
            write-build Green "Task $($task.name)` - In Master branch, marking for General Availability publish"
            [Switch]$SCRIPT:IsGARelease = $true
        }
    }

    #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
}

#Copy all powershell module "artifacts" to Build Directory
task CopyFilesToBuildDir {

    #Make sure we are in the project location in case something changed
    Set-Location $buildRoot

    #The file or file paths to copy, excluding the powershell psm1 and psd1 module and manifest files which will be autodetected
    copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $BuildReleasePath @PassThruParams
}

#Update the Metadata of the module with the latest version information.
task UpdateMetadata Version,CopyFilesToBuildDir,{
    # Update-ModuleManifest butchers PrivateData, using update-metadata from BuildHelpers instead.
    # Set the Module Version to the calculated Project Build version. Cannot use update-modulemanifest for this because it will complain the version isn't correct (ironic)
    Update-Metadata -Path $buildReleaseManifest -PropertyName ModuleVersion -Value $ProjectBuildVersion

    #Update Plaster Manifest Version
    $PlasterManifestPath = "$buildReleasePath\PlasterManifest.xml"
    $PlasterManifest = [xml](Get-Content -raw $PlasterManifestPath)
    $PlasterManifest.plasterManifest.metadata.version = $ProjectBuildVersion.tostring()
    $PlasterManifest.save($PlasterManifestPath)

    # This is needed for proper discovery by get-command and Powershell Gallery
    $moduleFunctionsToExport = (Get-ChildItem "$BuildReleasePath\Public" -Filter *.ps1).basename
    if (-not $moduleFunctionsToExport) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
    } else {
        Update-Metadata -Path $BuildReleaseManifest -PropertyName FunctionsToExport -Value $moduleFunctionsToExport
    }

    if ($IsGARelease) {
        #Blank out the prerelease tag to make this a GA build in Powershell Gallery
        $ProjectPreReleaseTag = ''
    } else {
        $Script:ProjectVersion = $ProjectPreReleaseVersion

        #Create an empty file in the root directory of the module for easy identification that its not a valid release.
        "This is a prerelease build and not meant for deployment!" > (Join-Path $BuildReleasePath "PRERELEASE-$ProjectVersion")
    }

    #Set the prerelease version in the Manifest File
    Update-Metadata -Path $BuildReleaseManifest -PropertyName PreRelease -value $ProjectPreReleaseTag

    if ($isTagRelease) {
        #Set an email address for the tag commit to work if it isn't already present
        if (-not (git config user.email)) {
            git config user.email "buildtag@$env:ComputerName"
        }

        #Tag the release. This keeps Gitversion performant, as well as provides a master audit trail
        if (-not (git tag -l "v$ProjectVersion")) {
            git tag "v$ProjectVersion" -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        } else {
            write-warning "Tag $ProjectVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen."
        }
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

    # In Appveyor? Upload our test results!
    If ($ENV:APPVEYOR) {
        $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        write-verbose "Detected we are running in AppVeyor! Uploading Pester Results to $UploadURL"
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $PesterResultFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
        $SCRIPT:SkipPublish = $true
    }
    "`n"
}

task Package Version,PreDeploymentChecks,{
    $ZipArchivePath = (join-path $env:BHBuildOutput "$env:BHProjectName-$ProjectVersion.zip")
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

task PreDeploymentChecks Test,{
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
        throw "Pester tests failed, or unable to detect a clean passing Pester Test nunit xml file in the $BuildOutput directory. Refusing to publish/deploy until all tests pass."
    }
    finally {
        $ErrorActionPreference = $CurrentErrorActionPreference
    }

    if (($BranchName -match '^(master$|releases?[-/])') -or $ForcePublish) {
        if (-not (Get-Item $BuildReleasePath/*.psd1 -erroraction silentlycontinue)) {throw "No Powershell Module Found in $BuildReleasePath. Skipping deployment. Did you remember to build it first with {Invoke-Build Build}?"}
    } else {
        write-build Magenta "Task $($task.name)` - We are not in master or release branch, skipping publish. If you wish to publish anyways such as for testing, run {InvokeBuild Publish -ForcePublish:$true}"
        $script:SkipPublish=$true
    }
}

task PublishGitHubRelease -if (-not $SkipPublish) Package,Test,{
    #Determine if GitHub is in use
    [uri]$gitOriginURI = & git remote get-url --push origin

    if ($gitOriginURI.host -eq 'github.com') {
        if (-not $GitHubUserName) {
            $GitHubUserName = $gitOriginURI.Segments[1] -replace '/$',''
        }
        [uri]$GitHubPublishURI = $gitOriginURI -replace '^https://github.com/(\w+)/(\w+).git','https://api.github.com/repos/$1/$2/releases'
        write-build Green "Using GitHub Releases URL: $GitHubPublishURI with user $GitHubUserName"
    } else {
        write-build DarkYellow "This project did not detect a GitHub repository as its git origin, skipping GitHub Release preparation"
        $SkipGitHubRelease = $true
    }

    if ($SkipPublish) {[switch]$SkipGitHubRelease = $true}
    if ($AppVeyor -and -not $GitHubAPIKey) {
        write-build DarkYellow "Task $($task.name) - Couldn't find GitHubAPIKey in the Appveyor secure environment variables. Did you save your Github API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }

    if (-not $GitHubAPIKey) {
        if (get-command 'get-storedcredential') {
            write-build Green "Detected Github API key in Windows Credential Manager, using that for GitHub Release"
            $WinCredMgrGitAPIKey = get-storedcredential -target 'LegacyGeneric:target=git:https://github.com' -erroraction silentlycontinue
            if ($WinCredMgrGitAPIKey) {
                $GitHubAPIKey = $winCredMgrGitAPIKey.GetNetworkCredential().Password
            }
        } else {
            #TODO: Add Linux credential support, preferably thorugh making a module called PoshAuth or something
            write-build DarkYellow "Task $($task.name) - GitHubAPIKey was not found as an environment variable or in the Windows Credential Manager. Please store it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
            $SkipGitHubRelease = $true
        }

    }
    if (-not $GitHubUserName) {
        write-build DarkYellow "Task $($task.name) - GitHubUserName was not found as an environment variable or inferred from the repository. Please specify it or use {Invoke-Build publish -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }

    #Checkpoint
    if ($SkipGitHubRelease) {
        write-build Magenta "Task $($task.name) - Skipping Publish to GitHub Releases"
        continue
    }
    #Inspiration from https://www.herebedragons.io/powershell-create-github-release-with-artifact

    #Create the release
    #Currently all releases are draft on publish and must be manually made public on the website or via the API
    $releaseData = @{
        tag_name = [string]::Format("v{0}", $ProjectVersion);
        target_commitish = "master";
        name = [string]::Format("v{0}", $ProjectVersion);
        body = $env:BHCommitMessage;
        draft = $false;
        prerelease = $true;
    }

    #Only master builds are considered GA
    if ($BranchName -eq 'master') {
        $releasedata.prerelease = $false
    }

    if ($GitHubPublishAsDraft) {$releasedata.draft = $true}

    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($GitHubApiKey + ":x-oauth-basic"))
    $releaseParams = @{
        Uri = $GitHubPublishURI
        Method = 'POST'
        Headers = @{
            Authorization = $auth
        }
        ContentType = 'application/json'
        Body = (ConvertTo-Json $releaseData -Compress)
    }

    try {
        #Invoke-Restmethod on WindowsPowershell always throws a terminating error regardless of erroraction setting, hence the catch. PSCore fixes this.
        $result = Invoke-RestMethod @releaseParams -ErrorVariable GitHubReleaseError
    } catch [System.Net.WebException] {
        #Git Hub Error Processing
        $gitHubErrorInfo = $PSItem.tostring() | convertfrom-json
        if ($gitHubErrorInfo) {
            write-build Red "Error Received from $($releaseparams.uri.host): $($GitHubErrorInfo.Message)"
            switch ($GitHubErrorInfo.message) {
                "Validation Failed" {
                    $gitHubErrorInfo.errors | foreach {
                        write-build Red "Task $($task.name) - Resource: $($PSItem.resource) - Field: $($PSItem.field) - Issue: $($PSItem.code)"

                        #Additional suggestion if release exists
                        if ($PSItem.field -eq 'tag_name' -and $PSItem.resource -eq 'Release' -and $PSItem.code -eq 'already_exists') {
                            write-build DarkYellow "Task $($task.name) - NOTE: This usually means you've already published once for this commit. This is common if you try to publish again on the same commit. For safety, we will not overwrite releases with same version number. Please make a new commit (empty is fine) to bump the version number, or delete this particular release on Github and retry (NOT RECOMMENDED). You can also mark it as a draft release with the -GitHubPublishAsDraft, multiple drafts per version are allowed"
                        }
                    }
                }
            }

            if ($PSItem.documentation_url) {write-build Red "More info at $($PSItem.documentation_url)"}
        } else {throw}

    }

    if ($GitHubReleaseError) {
        #Dont bother uploading if the release failed
        throw $GitHubErrorInfo
    }

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

task PublishPSGallery -if (-not $SkipPublish) Test,{
    if ($SkipPublish) {[switch]$SkipPSGallery = $true}
    if ($AppVeyor -and -not $NuGetAPIKey) {
        write-build DarkYellow "Task $($task.name) - Couldn't find NuGetAPIKey in the Appveyor secure environment variables. Did you save your NuGet/Powershell Gallery API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://www.appveyor.com/docs/build-configuration/"
        $SkipPSGallery = $true
    }
    if (-not $NuGetAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow "Task $($task.name) - NuGetAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build publish -NuGetAPIKey "MyAPIKeyString"}. Have you registered for a Powershell Gallery API key yet? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item"
        $SkipPSGallery = $true
    }

    if ($SkipPSGallery) {
        Write-Build Magenta "Task $($task.name) - Skipping Powershell Gallery Publish"
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

#Default Task - Build and Test
task . Clean,Build,Test,Package