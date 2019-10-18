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
    #Specify a directory to search for Powershell Module manifests, used for module autodetection. NOTE: This will use the manifest closest to the root of the search path
    [Parameter(ParameterSetName='Search')][string]$ModuleSearchPath = (Get-Location),
    #How far up the directory tree to recursively search for module manifests.
    [Parameter(ParameterSetName='Search')][int]$Depth=0
)

Describe 'Powershell Module' {
    BeforeAll {
        if (-not $ModuleManifestPath) {
            #If we are in a folder named 'Tests', search the parent folder
            if ((get-location | split-path -leaf) -match '^Tests?$') {
                $Depth=1
            }

            $CurrentModuleSearchPath = $ModuleSearchPath
            $i=0
            while ($i -le $Depth) {
                write-verbose "Searching for Powershell Module Manifests in $CurrentModuleSearchPath"
                $ModuleManifestPath = BuildHelpers\Get-PSModuleManifest -WarningAction SilentlyContinue $CurrentModuleSearchPath
                if ($ModuleManifestPath) {break}
                $CurrentModuleSearchPath = Split-Path $CurrentModuleSearchPath
                $i++
            }
        }

        if (-not $ModuleManifestPath) {throw "No powershell module manifest was detected. Please set your working directory to the Powershell Module Folder before starting this test. You may specify one explicitly to this Pester test with the -ModuleManifestPath option"}

        #If an alternate module root was specified, set that to our running directory.
        $ModuleDirectory = Split-Path $ModuleManifestPath

        #Set our path to the detected module directory, if required
        if ($ModuleDirectory -and $ModuleDirectory -ne $pwd.path) {Push-Location $ModuleDirectory}

        #Getting a FileInfo object because it has more metadata then a simple string path.
        $SCRIPT:ModuleManifestFile = Get-Item $ModuleManifestPath -ErrorAction Stop
    }

    $ModuleName = $ModuleManifestFile.basename
    Context ($ModuleName) {
        It 'Has a valid Module Manifest' {
            if ($PSEdition -eq 'Core') {
                $Script:Manifest = Test-ModuleManifest $ModuleManifestFile -Verbose:$false
            } else {
                #Copy the Module Manifest to a temp file for testing. This fixes a bug where
                #Test-ModuleManifest caches the first result, thus not catching changes if subsequent tests are run
                $TempModuleManifestPath = [IO.Path]::GetTempFileName() + '.psd1'
                copy-item $ModuleManifestFile $TempModuleManifestPath
                $Script:Manifest = Test-ModuleManifest $TempModuleManifestPath -Verbose:$false
                remove-item $TempModuleManifestPath -verbose:$false
            }
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid root module' {
            Test-Path $Manifest.RootModule -Type Leaf | Should Be $true
        }

        It 'Has a valid folder structure (ModuleName\Manifest or ModuleName\Version\Manifest)' {
            $moduleDirectoryErrorMessage = "Module directory structure doesn't match either $ModuleName or $moduleName\$($Manifest.Version)"
            $ModuleManifestDirectory = $ModuleManifestFile.directory
            switch ($ModuleManifestDirectory.basename) {
                $ModuleName {$true}
                $Manifest.Version.toString() {
                    if ($ModuleManifestDirectory.parent -match $ModuleName) {$true} else {throw $moduleDirectoryErrorMessage}
                }
                default {throw $moduleDirectoryErrorMessage}
            }
        }

        It 'Has a valid Description' {
            $Manifest.Description | Should Not BeNullOrEmpty
        }

        It 'Has a valid GUID' {
            [Guid]$Manifest.Guid | Should BeOfType 'System.GUID'
        }

        It 'Has a valid Copyright' {
            $Manifest.Copyright | Should Not BeNullOrEmpty
        }

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

        It 'Can be imported as a module successfully' {
            #Make sure an existing module isn't present
            Remove-Module $ModuleManifestFile.basename -ErrorAction SilentlyContinue
            $SCRIPT:BuildOutputModule = Import-Module $ModuleManifestFile -PassThru -verbose:$false -erroraction stop
            $BuildOutputModule.Name | Should Be $ModuleName
            $BuildOutputModule | Should BeOfType System.Management.Automation.PSModuleInfo
        }
        It 'Can be removed as a module' {
            $BuildOutputModule | Remove-Module -erroraction stop -verbose:$false | Should BeNullOrEmpty
        }

    }
}
Describe 'Powershell Gallery Readiness (PSScriptAnalyzer)' {
    $results = Invoke-ScriptAnalyzer -Path $ModuleManifestFile.directory -Recurse -Setting PSGallery -Severity Error -Verbose:$false
    It 'PSScriptAnalyzer returns zero errors (warnings OK) using the Powershell Gallery ruleset' {
        if ($results) {write-warning ($results | Format-Table -autosize | out-string)}
        $results.Count | Should Be 0
    }
}


#Return to where we started
Pop-Location