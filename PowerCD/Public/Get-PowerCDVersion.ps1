using namespace System.IO
function Get-PowerCDVersion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Version]$GitVersionVersion = '5.2.4'
    )

    $GitVersionExe = 'dotnet dotnet-gitversion /nofetch'
    try {
        #Calculate the GitVersion
        write-verbose "Executing GitVersion to determine version info"
        $GitVersionOutput = Invoke-Expression $GitVersionEXE
        if (-not $GitVersionOutput) {throw "GitVersion returned no output. Are you sure it ran successfully?"}

        #Since GitVersion doesn't return error exit codes, we look for error text in the output
        if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe in $buildRoot"}
        $SCRIPT:GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop

        if ($PCDSetting.Debug) {
            Invoke-Expression "$GitVersionExe /diag"  | write-debug
        }

        $GitVersionInfo | format-list | out-string | write-verbose

        [Version]$PCDSetting.Version     = $GitVersionInfo.MajorMinorPatch

        #TODO: Older packagemanagement don't support hyphens in Nuget name for some reason. Restore when fixed
        #[String]$PCDSetting.PreRelease   = $GitVersionInfo.NuGetPreReleaseTagV2
        #[String]$PCDSetting.VersionLabel = $GitVersionInfo.NuGetVersionV2
        #Remove separator characters for now, for instance in branch names
        [String]$PCDSetting.PreRelease   = $GitVersionInfo.NuGetPreReleaseTagV2 -replace '[\/\\\-]',''
        [String]$PCDSetting.VersionLabel = $PCDSetting.Version,$PCDSetting.PreRelease -join '-'

        if ($PCDSetting.BuildEnvironment.BuildOutput) {
            $PCDSetting.BuildModuleOutput = [io.path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,$PCDSetting.BuildEnvironment.ProjectName,$PCDSetting.Version)
        }
    } catch {
        write-warning "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is below...`r`n$GitVersionOutput"
        & $GitVersionexe /diag
        throw 'Exiting due to failed Gitversion execution'
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
}