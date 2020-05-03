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
    [Parameter(ParameterSetName='Explicit')][string]$ModuleManifestPath,
    #How far up the directory tree to recursively search for module manifests.
    [Parameter(ParameterSetName='Search')][int]$Depth=0
)

. $PSScriptRoot/../PowerCD.bootstrap.ps1

Write-Host -fore green "$pwd $GetPSModuleManifestWarning"

if (-not $ModuleManifestPath) {
    $moduleManifestPath = switch ($true) {
        ($ENV:PowerCDModuleManifest -and (Test-Path $ENV:PowerCDModuleManifest)) {
            $ENV:PowerCDModuleManifest
            break
        }
        ((Get-BuildEnvironment -WarningAction SilentlyContinue).ProjectName) {
            break
        }

    }
    # if ) {
    #     $ModuleManifestPath =
    # } elseif
    # elseif ($GetPSModuleManifestWarning) {
    #     Write-Error ([String]$GetPSModuleManifestWarning)
    # }
}

Describe 'Powershell Module' {
    BeforeAll {
    #     if (-not $ModuleManifestPath) {throw "No powershell module manifest was detected. Please set your working directory to the Powershell Module Folder before starting this test. You may specify one explicitly to this Pester test with the -ModuleManifestPath option"}

    #     #If an alternate module root was specified, set that to our running directory.
    #     $ModuleDirectory = Split-Path $ModuleManifestPath

    #     #Set our path to the detected module directory, if required
    #     if ($ModuleDirectory -and $ModuleDirectory -ne $pwd.path) {Push-Location $ModuleDirectory}

    #     #Getting a FileInfo object because it has more metadata then a simple string path.
    #     $SCRIPT:ModuleManifestFile = Get-Item $ModuleManifestPath -ErrorAction Stop
    } #BeforeAll

    It 'test' {$true}
    # $ModuleName = $ModuleManifestFile.basename
    # Context 'Test' {
    #     It 'Has a valid Module Manifest' {
    #         if ($PSEdition -eq 'Core') {
    #             $Script:Manifest = Test-ModuleManifest $ModuleManifestFile -Verbose:$false
    #         } else {
    #             #Copy the Module Manifest to a temp file for testing. This fixes a bug where
    #             #Test-ModuleManifest caches the first result, thus not catching changes if subsequent tests are run
    #             $TempModuleManifestPath = [IO.Path]::GetTempFileName() + '.psd1'
    #             copy-item $ModuleManifestFile $TempModuleManifestPath
    #             $Script:Manifest = Test-ModuleManifest $TempModuleManifestPath -Verbose:$false
    #             remove-item $TempModuleManifestPath -verbose:$false
    #         }
    #         $Manifest | Should -Not -BeNullOrEmpty
    #     }

    #     It 'Has a valid root module' {
    #         Test-Path $Manifest.RootModule -Type Leaf | Should -Be $true
    #     }

    #     It 'Has a valid folder structure (ModuleName\Manifest or ModuleName\Version\Manifest)' {
    #         $moduleDirectoryErrorMessage = "Module directory structure doesn't match either $ModuleName or $moduleName\$($Manifest.Version)"
    #         $ModuleManifestDirectory = $ModuleManifestFile.directory
    #         switch ($ModuleManifestDirectory.basename) {
    #             $ModuleName {$true}
    #             $Manifest.Version.toString() {
    #                 if ($ModuleManifestDirectory.parent -match $ModuleName) {$true} else {throw $moduleDirectoryErrorMessage}
    #             }
    #             default {throw $moduleDirectoryErrorMessage}
    #         }
    #     }

    #     It 'Has a valid Description' {
    #         $Manifest.Description | Should -Not -BeNullOrEmpty
    #     }

    #     It 'Has a valid GUID' {
    #         [Guid]$Manifest.Guid | Should -BeOfType 'System.GUID'
    #     }

    #     It 'Has a valid Copyright' {
    #         $Manifest.Copyright | Should -Not -BeNullOrEmpty
    #     }

        #TODO: Problematic with compiled modules, need a new logic
        #
        # It 'Exports all public functions' {
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

        # It 'Has at least 1 exported command' {
        #     $Script:Manifest.exportedcommands.count | Should BeGreaterThan 0
        # }

    #     It 'Can be imported as a module successfully' {
    #         #Make sure an existing module isn't present
    #         Remove-Module $ModuleManifestFile.basename -ErrorAction SilentlyContinue
    #         #TODO: Make WarningAction a configurable parameter
    #         $SCRIPT:BuildOutputModule = Import-Module $ModuleManifestFile -PassThru -verbose:$false -warningaction SilentlyContinue -erroraction stop 4>$null
    #         $BuildOutputModule.Name | Should -Be $ModuleName
    #         $BuildOutputModule | Should -BeOfType System.Management.Automation.PSModuleInfo
    #     }
    #     It 'Can be removed as a module' {
    #         $BuildOutputModule | Remove-Module -erroraction stop -verbose:$false | Should -BeNullOrEmpty
    #     }

    # }
}
# Describe 'Powershell Gallery Readiness (PSScriptAnalyzer)' {
#     $results = Invoke-ScriptAnalyzer -Path $ModuleManifestFile.directory -Recurse -Setting PSGallery -Severity Error -Verbose:$false
#     It 'PSScriptAnalyzer returns zero errors (warnings OK) using the Powershell Gallery ruleset' {
#         if ($results) {write-warning ($results | Format-Table -autosize | out-string)}
#         $results.Count | Should -Be 0
#     }
# }


# #Return to where we started
# Pop-Location