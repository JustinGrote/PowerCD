#requires -version 5
#Build Script for Powershell Modules
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

param (
    #Skip deployment and packaging
    [Switch]$SkipDeploy,
    #Skip publishing to various destinations (Appveyor,Github,PowershellGallery,etc.)
    [Switch]$SkipPublish,
    #Force deployment step even if we are not in master. If you are following GitFlow or GitHubFlow you should never need to do this.
    [Switch]$ForceDeploy,
    #Show detailed environment variables. WARNING: Running this in a CI like appveyor may expose your secrets to the log! Be careful!
    [Switch]$ShowEnvironmentVariables,
    #Powershell modules required for the build process
    [String[]]$BuildHelperModules = @("BuildHelpers","Pester","powershell-yaml","Microsoft.Powershell.Archive","PSScriptAnalyzer"),
    #Which build files/folders should be excluded from packaging
    [String[]]$BuildFilesToExclude = @("Build","Release","Tests",".git*","appveyor.yml","gitversion.yml","*.build.ps1",".vscode",".placeholder"),
    #Where to perform the building of the module. Defaults to "Release" under the project directory
    [String]$BuildOutputPath,
    #NuGet API Key for Powershell Gallery Deployment. Defaults to environment variable of the same name
    [String]$NuGetAPIKey = $env:NuGetAPIKey,
    #GitHub User for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubUserName = $env:GitHubAPIKey,
    #GitHub API Key for Github Releases. Defaults to environment variable of the same name
    [String]$GitHubAPIKey = $env:GitHubAPIKey
)

#Initialize Build Environment
Enter-Build {
    #TODO: Make bootstrap module loading more flexible and dynamic
    $HelpersPath = "$BuildRoot\Build\Helpers"
    import-module -force -name "$HelpersPath\BuildHelpers"
    $GitVersionEXE = "$BuildRoot\Build\Helpers\GitVersion\GitVersion.exe"

    #Set the buildOutputPath to "Releases" by default if not otherwise specified
    if (-not $BuildOutputPath) {
        $BuildOutputPath = "$BuildRoot\Release"
    }

    #Initialize BuildHelper variables as build scope variables for use by all tasks
    foreach ($BHVariableItem in (Get-BuildEnvironment -BuildOutput $BuildOutputPath).psobject.properties) {
        New-Variable -Name ("BH" + $BHVariableItem.Name) -Value ($BHVariableItem.Value)
    }

    #Define the Project Build Path
    $ProjectBuildPath = $BHBuildOutput + "\" + $BHProjectName
    Write-Build Green "Build Initialization: Project Build Path - $ProjectBuildPath"

    #If the branch name is master-test, run the build like we are in "master"
    if ($BHBranchName -eq 'master-test') {
        write-build Magenta "Build Initialization: Detected master-test branch, running as if we were master"
        $SCRIPT:BranchName = "master"
    } else {
        $SCRIPT:BranchName = $BHBranchName
    }
    write-build Green "Build Initialization: Current Branch Name: $BranchName"

    if ( ($VerbosePreference -ne 'SilentlyContinue') -or ($CI -and ($BranchName -ne 'master')) ) {
        write-build Green "Build Initialization: Verbose Build Logging Enabled"
        $SCRIPT:VerbosePreference = "Continue"
        $PassThruParams.Verbose = $true
    }
    $PassThruParams = @{}

    #Initialize Script-scope variables to be populated later
    $ArtifactPaths = @()
    $ProjectBuildVersion = $null

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
        write-build Green 'Build Initialization: Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        $ProgressPreference = "SilentlyContinue"
    }

    #Fetch Build Helper Modules using Install-ModuleBootstrap script (works in PSv3/4)
    #The comma in ArgumentList a weird idiosyncracy to make sure a nested array is created to ensure Argumentlist
    #doesn't unwrap the buildhelpermodules as individual arguments
    #We suppress verbose output for master builds (because they should have already been built once cleanly)
    foreach ($BuildHelperModuleItem in $BuildHelperModules) {
        if (-not (Get-module $BuildHelperModuleItem -listavailable)) {
            write-verbose "Build Initialization: Installing $BuildHelperModuleItem from Powershell Gallery to your currentuser module directory"
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                write-verboseheader "Bootstrapping Powershell Module: $BuildHelperModuleItem"
                Invoke-Command -ArgumentList @(, $BuildHelperModules) -ScriptBlock ([scriptblock]::Create((new-object net.webclient).DownloadString('https://git.io/PSModBootstrap')))
            } else {
                $installModuleParams = @{
                    Scope = "CurrentUser"
                    Name = $BuildHelperModuleItem
                    ErrorAction = "Stop"
                }
                if ($SCRIPT:CI) {
                    $installModuleParams.Force = $true
                }
                install-module @installModuleParams
            }
        }
    }

    #Initialize helpful build environment variables
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major

    #Broke this on purpose #TODO: Remove once all variables are cleaned up
    #Set-BuildEnvironment -force

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
    }

    #Add the nuget repository so we can download things like GitVersion
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
    if (test-path $BHBuildOutput) {
        Write-Verbose "Removing and resetting Build Output Path: $($BHBuildOutput)"
        remove-item $BHBuildOutput -Recurse -Force @PassThruParams
    }
    New-Item -ItemType Directory $ProjectBuildPath -force @PassThruParams | out-null
    #Unmount any modules named the same as our module
    Remove-Module (Get-ProjectName) -erroraction silentlycontinue
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$buildRoot/GitVersion.yml"

    #Fetch GitVersion
    #TODO: Use Nuget.exe to fetch to make this v3/v4 compatible
    if (-not $GitVersion) {
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
    if (Test-Path $BHPSModuleManifest) {
        write-verbose "Fetching Version from Powershell Module Manifest (if present)"
        $ModuleManifestVersion = [Version](Get-Metadata $BHPSModuleManifest)
        write-verbose "Getting the version in GitVersion.yml and overriding if necessary"
        if (Test-Path $buildRoot/GitVersion.yml) {
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

    #Calcuate the GitVersion
    write-verbose "Executing GitVersion to determine version info"
    $GitVersionCommand = "$GitVersionEXE $buildRoot"
    $GitVersionOutput = Invoke-BuildExec { & $GitVersionEXE $buildRoot}

    #Since GitVersion doesn't return error exit codes, we look for error text in the output in the output
    if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe $buildRoot"}
    try {
        $GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop
    } catch {
        throw "There was an error when running GitVersion.exe $buildRoot. The output of the command (if any) follows:"
        $GitVersionOutput
    }

    write-verboseheader "GitVersion Results"
    $GitVersionInfo | format-list | out-string | write-verbose

    #If we are in the develop branch, add the prerelease number as revision
    #TODO: Make the develop and master regex customizable in a settings file
    if ($BranchName -match '^dev(elop)?(ment)?$') {
        $SCRIPT:ProjectBuildVersion = ($GitVersionInfo.MajorMinorPatch + "." + $GitVersionInfo.PreReleaseNumber)
    } else {
        $SCRIPT:ProjectBuildVersion = [Version] $GitVersionInfo.MajorMinorPatch
    }

    $SCRIPT:ProjectSemVersion = $($GitVersionInfo.fullsemver)
    write-build Green "Task $($task.name)`: Using Project Version: $ProjectBuildVersion"
    write-build Green "Task $($task.name)`: Using Project Version (Extended): $($GitVersionInfo.fullsemver)"
}

#Copy all powershell module "artifacts" to Build Directory
task CopyFilesToBuildDir {
    #Make sure we are in the project location in case somethign changedf
    Set-Location $buildRoot

    #The file or file paths to copy, excluding the powershell psm1 and psd1 module and manifest files which will be autodetected
    #TODO: Move this somewhere higher in the hierarchy into a settings file, or rather go the "exclude" route
    $FilesToCopy = "lib","Public","Private","Types","LICENSE","README.md","$BHProjectName.psm1","$BHProjectName.psd1"
    copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $ProjectBuildPath @PassThruParams
}

#Update the Metadata of the Module with the latest Version
task UpdateMetadata Version,CopyFilesToBuildDir,{
    <# TODO: Fix this logic to allow for dynamic parameters, it's too flaky right now. Just going to assume all public functions for now line up
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    # Because this loads/locks assembiles and can affect cleans in the same session, copy it to a temporary location, find the changes, and apply to original module.
    # TODO: Find a cleaner solution, like update Set-ModuleFunctions to use a separate runspace or include a market to know we are in ModuleFunctions so when loading the module we can copy the assemblies to temp files first
    $ProjectBuildManifest = ($ProjectBuildPath + "\" + (split-path $env:BHPSModuleManifest -leaf))
    $tempModuleDir = [System.IO.Path]::GetTempFileName()
    Remove-Item $tempModuleDir -verbose:$false
    New-Item -Type Directory $tempModuleDir | out-null
    copy-item -recurse $ProjectBuildPath/* $tempModuleDir

    $TempModuleManifest = ($tempModuleDir + "\" + (split-path $env:BHPSModuleManifest -leaf))
    import-module $tempModuleManifest -force -verbose
    Set-ModuleFunctions $tempModuleManifest @PassThruParams
    $moduleFunctionsToExport = Get-MetaData -Path $tempModuleManifest -PropertyName FunctionsToExport
    if (-not $moduleFunctionsToExport) {
        write-warning "No functions found in the powershell module with manifest $TempModuleManifest. It may not have imported correctly. Leaving functions alone for now"
    } else {
        Update-Metadata -Path $ProjectBuildManifest -PropertyName FunctionsToExport -Value $moduleFunctionsToExport
    }
    #>

    #Lazy Method, maybe can get dynamic parameter method above to work someday and not be completely lame
    $ProjectBuildManifest = ($ProjectBuildPath + "\" + (split-path $BHPSModuleManifest -leaf))
    $ProjectBuildPath = Join-Path $BHBuildOutput $BHProjectName
    $moduleFunctionsToExport = (Get-ChildItem "$ProjectBuildPath\Public" -Filter *.ps1).basename
    if (-not $moduleFunctionsToExport) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
    } else {
        Update-Metadata -Path $ProjectBuildManifest -PropertyName FunctionsToExport -Value $moduleFunctionsToExport
    }

    # Set the Module Version to the calculated Project Build version
    Update-Metadata -Path $ProjectBuildManifest -PropertyName ModuleVersion -Value $ProjectBuildVersion

    # Are we in the master or develop/development branch? Bump the version based on the powershell gallery if so, otherwise add a build tag
    if ($BranchName -match '^(master|dev(elop)?(ment)?)$') {
        write-build Green "Task $($task.name)`: In Master/Develop branch, adding Tag Version $ProjectBuildVersion to this build"
        $Script:ProjectVersion = $ProjectBuildVersion
        if (-not (git tag -l $ProjectBuildVersion)) {
            git tag "$ProjectBuildVersion"
        } else {
            write-warning "Tag $ProjectBuildVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen"
        }
        <# TODO: Add some intelligent logic to tagging releases
        if (-not $CI) {
            git push origin $ProjectBuildVersion | write-verbose
        }
        #>
        <# TODO: Add a Powershell Gallery Check on the module
        if (Get-NextNugetPackageVersion -Name (Get-ProjectName) -ErrorAction SilentlyContinue) {
            Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value (Get-NextNugetPackageVersion -Name (Get-ProjectName))
        }
        #>
    } else {
        write-build Green "Task $($task.name)`: Not in Master/Develop branch, marking this as a feature prelease build"
        $Script:ProjectVersion = $ProjectSemVersion
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
        "This is a prerelease build and not meant for deployment!" > (Join-Path $ProjectBuildPath "PRERELEASE-$ProjectSemVersion")
    }

    # Add Release Notes from current version
    # TODO: Generate Release Notes from Github
    #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ReleaseNotes -Value ("$($env:APPVEYOR_REPO_COMMIT_MESSAGE): $($env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)")
}

#Pester Testing
task Pester {
    $ModuleManifestPath = Join-Path $ProjectBuildPath '\*.psd1'
    if (-not (Test-Path $ModuleManifestPath)) {throw "Module Manifest not found at $ModuleManifestPath. Did you run 'Invoke-Build Build' first?"}

    write-verboseheader "Starting Pester Tests..."
    $PesterResultFile = "$BHBuildOutput\$BHProjectName-TestResults_PS$PSVersion`_$TimeStamp.xml"

    $PesterParams = @{
        Script = "Tests"
        OutputFile = $PesterResultFile
        OutputFormat = "NunitXML"
        PassThru = $true
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
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
        $SkipDeploy = $true
    }
    "`n"
}

task Package Version,{
    $ZipArchivePath = (join-path $BHBuildOutput "$BHProjectName-$ProjectBuildVersion.zip")
    write-build green "Task $($task.name)`: Writing Finished Module to $ZipArchivePath"
    #Package the Powershell Module
    Compress-Archive -Path $ProjectBuildPath -DestinationPath $ZipArchivePath -Force @PassThruParams

    $SCRIPT:ArtifactPaths += $ZipArchivePath
    #If we are in Appveyor, push completed zip to Appveyor Artifact
    if ($env:APPVEYOR) {
        write-build Green "Task $($task.name)`: Detected Appveyor, pushing Powershell Module archive to Artifacts"
        Push-AppveyorArtifact $ZipArchivePath
    }
}

task PreDeploymentChecks {
    #Do not proceed if the most recent Pester test is not passing.
    $CurrentErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Stop"
        $MostRecentPesterTestResult = [xml]((Get-Content -raw (get-item "$BHBuildOutput/*-TestResults*.xml" | Sort-Object lastwritetime | Select-Object -last 1)))
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

    if (($BranchName -eq 'master') -or $ForceDeploy) {
        if (-not (Get-Item $ProjectBuildPath/*.psd1 -erroraction silentlycontinue)) {throw "No Powershell Module Found in $ProjectBuildPath. Skipping deployment. Did you remember to build it first with {Invoke-Build Build}?"}
    } else {
        write-build Magenta "Task $($task.name)`: We are not in master branch, skipping publish. If you wish to deploy anyways such as for testing, run {InvokeBuild Deploy -ForceDeploy:$true}"
        $script:SkipPublish=$true
    }
}

task PublishGitHubRelease -if (-not $SkipPublish) Package,{
    #TODO: Add Prerelease Logic when message commit says "!prerelease" or is in a release branch
    if ($AppVeyor -and -not $GitHubAPIKey) {
        write-build DarkYellow "Task $($task.name)`: Couldn't find GitHubAPIKey in the Appveyor secure environment variables. Did you save your Github API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }
    if (-not $GitHubAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow "Task $($task.name)`: `$env:GitHubAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build Deploy -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"

        $SkipGitHubRelease = $true
    }
    if (-not $GitHubUserName) {
        write-build DarkYellow "Task $($task.name)`: `$env:GitHubUserName was not found as an environment variable. Please specify it or use {Invoke-Build Deploy -GitHubUser `"MyGitHubUser`" -GitHubAPIKey `"MyAPIKeyString`"}. Have you created a GitHub API key with minimum public_repo scope permissions yet? https://github.com/settings/tokens"
        $SkipGitHubRelease = $true
    }
    if ($SkipGitHubRelease) {
        write-build Magenta "Task $($task.name): Skipping Publish to GitHub Releases"
    } else {
        #TODO: Add Prerelease Logic when message commit says "!prerelease" or is in a release branch
        #Inspiration from https://www.herebedragons.io/powershell-create-github-release-with-artifact

        #Create the release
        $releaseData = @{
            tag_name = [string]::Format("v{0}", $ProjectBuildVersion);
            target_commitish = "master";
            name = [string]::Format("v{0}", $ProjectBuildVersion);
            body = $BHCommitMessage;
            draft = $true;
            prerelease = $true;
        }
        $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($GitHubApiKey + ":x-oauth-basic"))
        $releaseParams = @{
            Uri = "https://api.github.com/repos/$gitHubUserName/$BHProjectName/releases"
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
    if ($AppVeyor -and -not $NuGetAPIKey) {
        write-build DarkYellow "Couldn't find NuGetAPIKey in the Appveyor secure environment variables. Did you save your NuGet/Powershell Gallery API key as an Appveyor Secure Variable? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item and https://www.appveyor.com/docs/build-configuration/"
        $SkipPSGallery = $true
    }
    if (-not $NuGetAPIKey) {
        #TODO: Add Windows Credential Store support and some kind of Linux secure storage or caching option
        write-build DarkYellow '$env:NuGetAPIKey was not found as an environment variable. Please specify it or use {Invoke-Build Deploy -NuGetAPIKey "MyAPIKeyString"}. Have you registered for a Powershell Gallery API key yet? https://docs.microsoft.com/en-us/powershell/gallery/psgallery/creating-and-publishing-an-item'
        $SkipPSGallery = $true
    }

    if ($SkipPSGallery) {
        Write-Build Magenta "Task $($task.name)`: Skipping Powershell Gallery Publish"
    } else {
        $publishParams = @{
                Path = $ProjectBuildPath
                NuGetApiKey = $NuGetAPIKey
                Repository = 'PSGallery'
                Force = $true
                ErrorAction = 'Stop'
                Confirm = $false
        }
        #TODO: Add Prerelease Logic when message commit says "!prerelease"
        Publish-Module @publishParams @PassThruParams
    }
}

### SuperTasks
# These are the only supported items to run directly from Invoke-Build
task Deploy PreDeploymentChecks,Package,PublishGitHubRelease,PublishPSGallery
task Build Version,Clean,CopyFilesToBuildDir,UpdateMetadata
task Test Pester

#Default Task - Build, Test with Pester, Deploy
task . Clean,Build,Test,Deploy