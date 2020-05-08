function Test-PowerCDPester {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        #Path where the Pester tests are located
        [Parameter(ParameterSetName='Default')][String]$Path = [String]$pwd,
        #Path where the coverage files should be output. Defaults to the build output path.
        [Parameter(ParameterSetName='Default')][String]$OutputPath = [String]$pwd,
        #A PesterConfiguration to use instead of the intelligent defaults. For advanced usage only.
        [Parameter(ParameterSetName='Configuration')][PesterConfiguration]$Configuration
    )
    if (-not $Configuration) {
        [PesterConfiguration]$Configuration = [PesterConfiguration]::Default
        #If we are in vscode, add the VSCodeMarkers
        if ($host.name -match 'Visual Studio Code') {
            Write-Verbose "Detected Visual Studio Code, adding Pester test markers"
            $Configuration.Debug.WriteVSCodeMarker = $true
            $Configuration.Debug.ShowNavigationMarkers = $true
        }
        #Temporary workaround for -CI not saving to variable
        #TODO: Remove when https://github.com/pester/Pester/issues/1527 is closed
        $Configuration.Output.Verbosity = 'Normal'
        $Configuration.Run.PassThru = $true
        $Configuration.Run.Path = $Path
        $Configuration.CodeCoverage.Enabled = $true
        $Configuration.CodeCoverage.OutputPath = "$OutputPath/CodeCoverage.xml"
        $Configuration.TestResult.Enabled = $true
        $Configuration.TestResult.OutputPath = "$OutputPath/TestResults.xml"
        $GLOBAL:TestResults = Invoke-Pester -Configuration $Configuration
    }

    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        $testFailedMessage = "Failed '$($TestResults.FailedCount)' tests, build failed"
        throw $testFailedMessage
        #TODO: Rewrite to use BuildHelpers
        # if ($isAzureDevOps) {
        #     Write-Host "##vso[task.logissue type=error;]$testFailedMessage"
        # }
        $SCRIPT:SkipPublish = $true
    }

    return

    # #Pester Configuration Setup
    # if (-not $Configuration) {
    #     $Configuration = [PesterConfiguration]::Default
    # }
    # $Configuration.OutputPath = $PesterResultFile

    # $Configuration.PesterResultFile = $Configuration
    # $Configuration.PesterResultFile = $Configuration
    # Invoke-Pester -Configuration $Configuration

    # [String[]]$Exclude = 'PowerCD.tasks.ps1',
    # $CodeCoverage = (Get-ChildItem -Path (Join-Path $ModuleDirectory '*') -Include *.ps1,*.psm1 -Exclude $Exclude -Recurse),
    # $Show = 'None',
    # [Switch]$UseJob
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



    if ($UseJob) {
        #Bootstrap PowerCD Prereqs
        $PowerCDModules = get-item (Join-Path ([io.path]::GetTempPath()) '/PowerCD/*/*/*.psd1')

        $PesterJob = {
            #Move to same folder as was started
            Set-Location $USING:PWD
            #Prepare the Destination Module Directory Environment
            $ENV:PowerCDModuleManifest = $USING:ModuleManifestPath
            #Bring in relevant environment
            $USING:PowerCDModules | Import-Module -Verbose:$false | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'}
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