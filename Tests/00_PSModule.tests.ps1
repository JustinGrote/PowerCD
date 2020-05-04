#Requires -Module @{ModuleName='BuildHelpers';MaximumVersion='2.0.11'}
#Requires -Module @{ModuleName='Pester';ModuleVersion='4.99.99';MaximumVersion='5.99.99'}

<#
.SYNOPSIS
This is a set of standard tests to ensure a powershell module is valid
.NOTES
This is designed to autodetect the powershell module, and follows the following discovery order:
1. If pester was invoked
#>
[CmdletBinding(DefaultParameterSetName='Search')]
param (
    #Specify an alternate location for the Powershell Module. This is useful when testing a build in another directory
    [Parameter(ParameterSetName='Explicit')][IO.FileInfo]$ModuleManifestPath,
    #How far up the directory tree to recursively search for module manifests.
    [Parameter(ParameterSetName='Search')][int]$Depth=0
)

#region TestSetup

. $PSScriptRoot/../PowerCD.bootstrap.ps1
#From PowerCD.bootstrap.ps1

#Automatic Manifest Detection if not specified
if (-not $ModuleManifestPath) {
    [IO.FileInfo]$SCRIPT:moduleManifestPath = switch ($true) {
        ($null -ne $GLOBAL:MetaBuildPath) {
            Write-Debug "Detected PowerCDModuleManifest MetaBuildPath Global Variable: $BHDetectedManifest"
            $GLOBAL:MetaBuildPath
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

#Detect if we are testing source vs. a "compiled" module. For now the logic for this is if the folder is versioned
#We skip some irrelevant tests such as the manifest exported functions, etc.
if ($ModuleManifestPath.basename -eq 'src' -or -not ($ModuleManifestPath.Basename -as [Version])) {
    $isSourceModule = $true
}
write-debug "Module Manifest Path = $ModuleManifestPath"

#endregion TestSetup
Describe 'Powershell Module' {

    # if ) {
    #     $ModuleManifestPath =
    # } elseif
    # elseif ($GetPSModuleManifestWarning) {
    #     Write-Error ([String]$GetPSModuleManifestWarning)
    # }

    #     if (-not $ModuleManifestPath) {throw "No powershell module manifest was detected. Please set your working directory to the Powershell Module Folder before starting this test. You may specify one explicitly to this Pester test with the -ModuleManifestPath option"}

    #     #If an alternate module root was specified, set that to our running directory.
    #     $ModuleDirectory = Split-Path $ModuleManifestPath

    #     #Set our path to the detected module directory, if required
    #     if ($ModuleDirectory -and $ModuleDirectory -ne $pwd.path) {Push-Location $ModuleDirectory}

    #     #Getting a FileInfo object because it has more metadata then a simple string path.
    #     $SCRIPT:ModuleManifestPath = Get-Item $ModuleManifestPath -ErrorAction Stop
    #BeforeAll

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
        It 'Has a valid Module Manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }
        It 'Has a valid root module' {
            #Test for the root module path relative to the module manifest
            Test-Path (Join-Path $ModuleManifestPath.directory $Manifest.RootModule) -Type Leaf | Should -BeTrue
        }

        It 'Has a valid Description' {
            $Manifest.Description | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid GUID' {
            [Guid]$Manifest.Guid | Should -BeOfType [Guid]
        }

        It 'Has a valid Copyright' {
            $Manifest.Copyright | Should -Not -BeNullOrEmpty

        }
        #TODO: Problematic with compiled modules, need a new logic
        #
        It 'Exports all public functions' -Skip:$isSourceModule {
            if ($isSourceModule) {
                #Set-ItResult is Broken in Pester5
                #TODO: Pester 5.1 fix when released
                #Set-ItResult -Pending -Because 'detection and approval of src style modules is pending'
                Write-Host -fore Yellow "SKIPPED: detection and approval of src style modules is pending"
                return
            }
            #TODO: Try PowerCD AST-based method
            $FunctionFiles = Get-ChildItem Public -Filter *.ps1
            $FunctionNames = $FunctionFiles.basename | ForEach-Object {$_ -replace '-', "-$($Manifest.Prefix)"}
            $ExFunctions = $Manifest.ExportedFunctions.Values.Name
            if ($ExFunctions -eq '*') {write-warning "Manifest has * for functions. You should individually specify your public functions prior to deployment for better discoverability"}
            if ($functionNames) {
                foreach ($FunctionName in $FunctionNames) {
                    $ExFunctions -contains $FunctionName | Should Be $true
                }
            }
        }

        It 'Has at least 1 exported command' -Skip:$isSourceModule {
            if ($isSourceModule) {
                #Set-ItResult is Broken in Pester5
                #TODO: Pester 5.1 fix when released
                #Set-ItResult -Pending -Because 'detection and approval of src style modules is pending'
                Write-Host -fore Yellow "SKIPPED: detection and approval of src style modules is pending"
                return
            }
            $Script:Manifest.exportedcommands.count | Should BeGreaterThan 0
        }

        It 'Has a valid Powershell module folder structure' -Skip:$isSourceModule {
            if ($isSourceModule) {
                #Set-ItResult is Broken in Pester5
                #TODO: Pester 5.1 fix when released
                #Set-ItResult -Pending -Because 'detection and approval of src style modules is pending'
                Write-Host -fore Yellow "SKIPPED: detection and approval of src style modules is pending"
                return
            }
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
    #     It 'Can be imported as a module successfully' {
    #         #Make sure an existing module isn't present
    #         Remove-Module $ModuleManifestPath.basename -ErrorAction SilentlyContinue
    #         #TODO: Make WarningAction a configurable parameter
    #         $SCRIPT:BuildOutputModule = Import-Module $ModuleManifestPath -PassThru -verbose:$false -warningaction SilentlyContinue -erroraction stop 4>$null
    #         $BuildOutputModule.Name | Should -Be $ModuleName
    #         $BuildOutputModule | Should -BeOfType System.Management.Automation.PSModuleInfo
    #     }
    #     It 'Can be removed as a module' {
    #         $BuildOutputModule | Remove-Module -erroraction stop -verbose:$false | Should -BeNullOrEmpty
    #     }

    # }
    } #Context

    # Context 'Powershell Gallery Readiness (PSScriptAnalyzer)' {
    #     $results = Invoke-ScriptAnalyzer -Path $ModuleManifestPath.directory -Recurse -Setting PSGallery -Severity Error -Verbose:$false
    #     It 'PSScriptAnalyzer returns zero errors (warnings OK) using the Powershell Gallery ruleset' {
    #         if ($results) {write-warning ($results | Format-Table -autosize | out-string)}
    #         $results.Count | Should -Be 0
    #     }
    # }
} #Describe





# #Return to where we started
# Pop-Location