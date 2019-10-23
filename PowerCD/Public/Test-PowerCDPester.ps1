
#Pester Testing
function Test-PowerCDPester {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]$ModuleManifestPath,
        $PesterResultFile = ([IO.Path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,"$($PCDSetting.BuildEnvironment.ProjectName)-$($PCDSetting.VersionLabel)-TestResults_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml")),
        $CodeCoverageOutputFile = ([IO.Path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,"$($PCDSetting.BuildEnvironment.ProjectName)-$($PCDSetting.VersionLabel)-CodeCoverage_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml")),
        [String[]]$Exclude = 'PowerCD.tasks.ps1',
        $CodeCoverage = (Get-ChildItem -Path (Join-Path $ModuleDirectory '*') -Include *.ps1,*.psm1 -Exclude $Exclude -Recurse),
        $Show = 'None',
        [Switch]$UseJob
    )

    #Try autodetecting the "furthest out module manifest"
    # if (-not $ModuleManifestPath) {
    #     try {
    #         $moduleManifestCandidatePath = Join-Path (Join-Path $PWD '*') '*.psd1'
    #         $moduleManifestCandidates = Get-Item $moduleManifestCandidatePath -ErrorAction stop
    #         $moduleManifestPath = ($moduleManifestCandidates | Select-Object -last 1).fullname
    #     } catch {
    #         throw "Did not detect any module manifests in $BuildProjectPath. Did you run 'Invoke-Build Build' first?"
    #     }
    # }

    #TODO: Update for new logging method
    #write-verboseheader "Starting Pester Tests..."
    Write-Verbose "Task $($task.name)` -  Testing $moduleManifestPath"

    $PesterParams = @{
        #TODO: Fix for source vs built object
        # Script       = @{
        #     Path = "Tests"
        #     Parameters = @{
        #         ModulePath = (Split-Path $moduleManifestPath)
        #     }
        # }
        OutputFile   = $PesterResultFile
        OutputFormat = 'NunitXML'
        PassThru     = $true
        OutVariable  = 'TestResults'
        Show         = $Show
    }

    if ($CodeCoverage) {
        $PesterParams.CodeCoverage = $CodeCoverage
        $PesterParams.CodeCoverageOutputFile = $CodeCoverageOutputFile
    }

    #If we are in vscode, add the VSCodeMarkers
    if ($host.name -match 'Visual Studio Code') {
        Write-Verbose "Detected Visual Studio Code, adding test markers"
        $PesterParams.PesterOption = (New-PesterOption -IncludeVSCodeMarker)
    }

    if ($UseJob) {
        #Bootstrap PowerCD Prereqs
        $PowerCDModules = get-item (Join-Path ([io.path]::GetTempPath()) '/PowerCD/*/*.psd1')

        $PesterJob = {
            #Move to same folder as was started
            Set-Location $USING:PWD
            #Prepare the Destination Module Directory Environment
            $ENV:PowerCDModuleManifest = $USING:ModuleManifestPath
            #Bring in relevant environment
            $USING:PowerCDModules | Import-Module -Force
            $PesterParams = $USING:PesterParams
            Invoke-Pester @PesterParams
        }

        $TestResults = Start-Job -ScriptBlock $PesterJob | Receive-Job -Wait
    } else {
        $ENV:PowerCDModuleManifest = $ModuleManifestPath
        $TestResults = Invoke-Pester @PesterParams
    }

    # In Appveyor? Upload our test results!
    #TODO: Consolidate Test Result Upload
    # If ($ENV:APPVEYOR) {
    #     $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    #     write-verbose "Detected we are running in AppVeyor! Uploading Pester Results to $UploadURL"
    #     (New-Object 'System.Net.WebClient').UploadFile(
    #         "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
    #         $PesterResultFile )
    # }

    #TODO: Fix to fail
    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        $testFailedMessage = "Failed '$($TestResults.FailedCount)' tests, build failed"
        throw $testFailedMessage
        #TODO: Rewrite to use BuildHelpers
        # if ($isAzureDevOps) {
        #     Write-Host "##vso[task.logissue type=error;]$testFailedMessage"
        # }
        $SCRIPT:SkipPublish = $true
    }
    # "`n"
}