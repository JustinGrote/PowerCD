#Requires -Module @{ModuleName='BuildHelpers';ModuleVersion='2.0.11'}
#Requires -Module @{ModuleName='Pester';ModuleVersion='5.0.0';MaximumVersion='5.99.99'}

<#
.SYNOPSIS
This is a set of standard tests to ensure a powershell module is valid
#>
[CmdletBinding(DefaultParameterSetName='Search')]
param (
    #Specify an alternate location for the Powershell Module. This is useful when testing a build in another directory
    [Parameter(ParameterSetName='Explicit')][IO.FileInfo]$ModuleManifestPath,
    #How far up the directory tree to recursively search for module manifests.
    [Parameter(ParameterSetName='Search')][int]$Depth=0
)
#region TestSetup
if (-not (Get-Module PowerCD)) {
    . ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap')))
}

#From PowerCD.bootstrap.ps1

#Automatic Manifest Detection if not specified
if (-not $ModuleManifestPath) {
    [IO.FileInfo]$SCRIPT:ModuleManifestPath = switch ($true) {
        #InvokeBuildDetection
        ($null -ne $BuildRoot -and $pcdsetting.outputmodulemanifest -and (Test-Path $pcdsetting.outputmodulemanifest)) {
            Write-Debug "Detected Invoke-Build and found a module built at: $($pcdsetting.outputmodulemanifest)"
            ($pcdsetting.outputmodulemanifest)
            break
        }
        ($null -ne $SCRIPT:MetaBuildPath) {
            Write-Debug "Detected PowerCDModuleManifest MetaBuildPath Global Variable: $BHDetectedManifest"
            $SCRIPT:MetaBuildPath
            break
        }
        ($ENV:PowerCDModuleManifest -and (Test-Path $ENV:PowerCDModuleManifest)) {
            Write-Debug "Detected PowerCDModuleManifest Environment Variable: $BHDetectedManifest"
            $ENV:PowerCDModuleManifest
            break
        }
        ($null -ne (
            Get-BuildEnvironment -WarningAction SilentlyContinue -OutVariable
            ).PSModuleManifest |
                Tee-Object -Variable $BHDetectedManifest
        ) {
            Write-Debug "Autodetected Powershell Module Manifest at $BHDetectedManifest"
            $BHDetectedManifest
            break
        }
        default {
            throw 'Could not detect the module'
        }
    }
}
#The parameter and scriptscope variable are separate entities so we use this to sync them
if ($SCRIPT:ModuleManifestPath) {$ModuleManifestPath = $SCRIPT:ModuleManifestPath}

#TODO: Better Source Module Detection
if ($ModuleManifestPath.basename -eq 'src' -or -not ($ModuleManifestPath.Directory.Directory.Basename -ne 'BuildOutput')) {
    $isSourceModule = $true
}
write-debug "Module Manifest Path = $SCRIPT:ModuleManifestPath"

#endregion TestSetup
Describe 'Powershell Module' -Tag PSModule {
    Context 'Manifest' {
        BeforeAll {
            if ($PSEdition -eq 'Core') {
                $Manifest = Test-ModuleManifest $ModuleManifestPath -Verbose:$false
            } else {
                #Workaround for: https://github.com/PowerShell/PowerShell/issues/2216
                $tempModuleManifestPath = Copy-Item $ModuleManifestPath TestDrive: -PassThru
                $Manifest = Test-ModuleManifest $TempModuleManifestPath -Verbose:$false
                Remove-Item $TempModuleManifestPath -verbose:$false
            }
        }
        It 'Has a valid Module Manifest' -Tag Unit {
            $Manifest | Should -Not -BeNullOrEmpty
        }
        It 'Has a valid root module' -Tag Unit {
            #Test for the root module path relative to the module manifest
            Test-Path (Join-Path $ModuleManifestPath.directory $Manifest.RootModule) -Type Leaf | Should -BeTrue
        }

        It 'Has a valid Description' -Tag Unit {
            $Manifest.Description | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid GUID' -Tag Unit {
            [Guid]$Manifest.Guid | Should -BeOfType [Guid]
        }

        It 'Has a valid Copyright' -Tag Unit {
            $Manifest.Copyright | Should -Not -BeNullOrEmpty

        }
        #TODO: Problematic with compiled modules, need a new logic
        # It 'Exports all public functions' -Skip:$isSourceModule {
        #     if ($isSourceModule) {
        #         #Set-ItResult is Broken in Pester5
        #         #TODO: Pester 5.1 fix when released
        #         #Set-ItResult -Pending -Because 'detection and approval of src style modules is pending'
        #         Write-Host -fore Yellow "SKIPPED: detection and approval of src style modules is pending"
        #         return
        #     }
        #     #TODO: Try PowerCD AST-based method
        #     $FunctionFiles = Get-ChildItem Public -Filter *.ps1
        #     $FunctionNames = $FunctionFiles.basename | ForEach-Object {$_ -replace '-', "-$($Manifest.Prefix)"}
        #     $ExFunctions = $Manifest.ExportedFunctions.Values.Name
        #     if ($ExFunctions -eq '*') {write-warning "Manifest has * for functions. You should individually specify your public functions prior to deployment for better discoverability"}
        #     if ($functionNames) {
        #         foreach ($FunctionName in $FunctionNames) {
        #             $ExFunctions -contains $FunctionName | Should Be $true
        #         }
        #     }
        # }

        It 'Has at least 1 exported command' -Skip:$isSourceModule -Tag Integration {
            $Manifest.exportedcommands.count | Should -BeGreaterThan 0
        }

        It 'Has a valid Powershell module folder structure' -Skip:$isSourceModule -Tag Integration {
            $ModuleName = $Manifest.Name
            $moduleDirectoryErrorMessage = "Module directory structure doesn't match either $ModuleName or $moduleName\$($Manifest.Version)"
            $ModuleManifestDirectory = $ModuleManifestPath.directory
            switch ($ModuleManifestDirectory.basename) {
                $ModuleName {$true}
                $Manifest.Version.toString() {
                    if ($ModuleManifestDirectory.parent -match $ModuleName) {$true} else {throw $moduleDirectoryErrorMessage}
                }
                default {throw $moduleDirectoryErrorMessage}
            }
        }
        It 'Can be imported as a module successfully' -Tag Integration {
            #TODO: #30 Start-Job doesn't work within a linux container

            #Make sure an existing module isn't present
            Remove-Module $ModuleManifestPath.basename -ErrorAction SilentlyContinue
            #TODO: Make WarningAction a configurable parameter
            $ImportModuleTestJob = {
                Import-Module $USING:ModuleManifestPath -PassThru -Verbose:$false -WarningAction SilentlyContinue
            }
            #Run the import test in an isolated job to avoid potential assembly locking
            $ImportModuleJob = Start-Job -ScriptBlock $ImportModuleTestJob
            $SCRIPT:BuildOutputModule =  $ImportModuleJob | Wait-Job | Receive-Job
            Remove-Job $ImportModuleJob
            $ModuleName = $Manifest.Name
            $BuildOutputModule.Name | Should -Be $ModuleName
        }
    } #Context

    Context 'PSScriptAnalyzer - Powershell Gallery Readiness' {
        It 'PSScriptAnalyzer returns zero errors (warnings OK) using the Powershell Gallery ruleset' {
            $results = Invoke-ScriptAnalyzer -Path $ModuleManifestPath.Directory -Recurse -Settings PSGallery -Severity Error -Verbose:$false

            if ($results) {Write-Warning ($results | Format-Table -autosize | Out-String)}
            $results.Count | Should -Be 0
        }
    }
} #Describe
