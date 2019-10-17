#TODO: Move this to Microsoft.Extensions.Configuration
function Get-PowerCDSetting {
    [CmdletBinding()]
    param (
        #Build Output Directory Name. Defaults to Get-BuildEnvironment Default which is 'BuildOutput'
        $BuildOutput = 'BuildOutput'
    )

    $Settings = [ordered]@{}

    $Settings.BuildEnvironment = (Get-BuildEnvironment -BuildOutput $BuildOutput -As Hashtable).AsReadOnly()

    $Settings.General = [ordered]@{
        # Root directory for the project
        ProjectRoot = $Settings.BuildEnvironment.ProjectPath

        # Root directory for the module
        SrcRootDir = $Settings.BuildEnvironment.ModulePath

        # The name of the module. This should match the basename of the PSD1 file
        ModuleName = $Settings.BuildEnvironment.ProjectName

        # Module version
        ModuleVersion = (Import-PowerShellDataFile -Path $Settings.BuildEnvironment.PSModuleManifest).ModuleVersion

        # Module manifest path
        ModuleManifestPath = $Settings.BuildEnvironment.PSModuleManifest
    }

    $Settings.Build = [ordered]@{
        Dependencies = @('StageFiles', 'BuildHelp')

        # Default Output directory when building a module
        OutDir = $Settings.BuildEnvironment.BuildOutput

        # Module output directory
        # This will be computed in 'Initialize-PSBuild' so we can allow the user to
        # override the top-level 'OutDir' above and compute the full path to the module internally
        ModuleOutDir = $Settings.BuildEnvironment.BuildOutput

        # Controls whether to "compile" module into single PSM1 or not
        CompileModule = $true

        # List of files to exclude from output directory
        Exclude = @()
    }


    $Settings.Test = [ordered]@{
        # Enable/disable Pester tests
        Enabled = $true

        # Directory containing Pester tests
        RootDir = Join-Path -Path $Settings.BuildEnvironment.ProjectPath -ChildPath tests

        # Specifies an output file path to send to Invoke-Pester's -OutputFile parameter.
        # This is typically used to write out test results so that they can be sent to a CI
        # system like AppVeyor.
        OutputFile = ([IO.Path]::Combine($Settings.Environment.BuildOutput,"$($Settings.Environment.ProjectName)-TestResults_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml"))

        # Specifies the test output format to use when the TestOutputFile property is given
        # a path.  This parameter is passed through to Invoke-Pester's -OutputFormat parameter.
        OutputFormat = 'NUnitXml'

        ScriptAnalysis = [ordered]@{
            # Enable/disable use of PSScriptAnalyzer to perform script analysis
            Enabled = $true

            # When PSScriptAnalyzer is enabled, control which severity level will generate a build failure.
            # Valid values are Error, Warning, Information and None.  "None" will report errors but will not
            # cause a build failure.  "Error" will fail the build only on diagnostic records that are of
            # severity error.  "Warning" will fail the build on Warning and Error diagnostic records.
            # "Any" will fail the build on any diagnostic record, regardless of severity.
            FailBuildOnSeverityLevel = 'Error'

            # Path to the PSScriptAnalyzer settings file.
            SettingsPath = Join-Path $PSScriptRoot -ChildPath ScriptAnalyzerSettings.psd1
        }

        CodeCoverage = [ordered]@{
            # Enable/disable Pester code coverage reporting.
            Enabled = $false

            # Fail Pester code coverage test if below this threshold
            Threshold = .75

            # CodeCoverageFiles specifies the files to perform code coverage analysis on. This property
            # acts as a direct input to the Pester -CodeCoverage parameter, so will support constructions
            # like the ones found here: https://github.com/pester/Pester/wiki/Code-Coverage.
            Files = @(
                Join-Path -Path $Settings.BuildEnvironment.ModulePath -ChildPath '*.ps1'
                Join-Path -Path $Settings.BuildEnvironment.ModulePath -ChildPath '*.psm1'
            )
        }
    }

    $Settings.Help  = [ordered]@{
        # Path to updateable help CAB
        UpdatableHelpOutDir = Join-Path -Path $Settings.Build.ModuleOutDir -ChildPath 'UpdatableHelp'

        # Default Locale used for help generation, defaults to en-US
        DefaultLocale = (Get-UICulture).Name

        # Convert project readme into the module about file
        ConvertReadMeToAboutHelp = $false
    }

    $Settings.Docs = [ordered]@{
        # Directory PlatyPS markdown documentation will be saved to
        RootDir = Join-Path -Path $Settings.Build.ModuleOutDir -ChildPath 'docs'
    }

    $Settings.Publish = [ordered]@{
        # PowerShell repository name to publish modules to
        PSRepository = 'PSGallery'

        # API key to authenticate to PowerShell repository with
        PSRepositoryApiKey = $env:PSGALLERY_API_KEY

        # Credential to authenticate to PowerShell repository with
        PSRepositoryCredential = $null
    }

    # Enable/disable generation of a catalog (.cat) file for the module.
    # [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    # $catalogGenerationEnabled = $true

    # # Select the hash version to use for the catalog file: 1 for SHA1 (compat with Windows 7 and
    # # Windows Server 2008 R2), 2 for SHA2 to support only newer Windows versions.
    # [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    # $catalogVersion = 2

    return $Settings
}
