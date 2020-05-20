<#
.SYNOPSIS
Initializes the build environment and detects various aspects of the environment
#>

function Initialize-PowerCD {
    [CmdletBinding()]
    param (
        #Specify this if you don't want initialization to switch to the folder build root
        [Switch]$SkipSetBuildRoot
    )
    Write-Host -fore cyan "Task PowerCD.Initialize"
    $bootstrapTimer = [Diagnostics.Stopwatch]::StartNew()

    #Fix a module import bug if powershell was started from pwsh. This is now fixed in PWSH7
    # if ($PSEdition -eq 'Desktop') {
    #     Reset-WinPSModules
    # }


    #PS5.1: Load a fairly new version of newtonsoft.json to maintain compatibility with other tools, if not present
    if ($PSEdition -eq 'Desktop') {
        [bool]$newtonsoftJsonLoaded = try {
            [bool]([newtonsoft.json.jsonconvert].assembly)
        } catch {
            $false
        }
        if (-not $NewtonsoftJsonLoaded) {
            #TODO: Remove this when PSGetv3 properly supports Powershell 5.1 - https://github.com/PowerShell/PowerShellGet/issues/122
            Write-Verbose "PowerCD: Newtonsoft.Json not loaded, bootstrapping for Windows Powershell and PSGetV3"

            $jsonAssemblyPath = Join-Path (Split-Path (Get-Module powercd).path) 'lib/Newtonsoft.Json.dll'
            if ($PowerCDMetaBuild) {
                $jsonAssemblyPath = Join-Path (Split-Path $PowerCDMetaBuild) 'lib/Newtonsoft.Json.dll'
                Write-Verbose "PowerCD: Meta Build Detected, Moving Newtonsoft.Json to Temporary Location"
                #Move the DLL to the localappdata folder to prevent an issue with zipping up the completed build
                $tempJsonAssemblyPath = Join-Path ([Environment]::GetFolderpath('LocalApplicationData')) 'PowerCD/Newtonsoft.Json.dll'
                New-Item -ItemType Directory -Force (Split-Path $tempJsonAssemblyPath) > $null
                Copy-Item $jsonAssemblyPath $tempJsonAssemblyPath -force > $null
                $jsonAssemblyPath = $tempJsonAssemblyPath
            }
            Add-Type -Path $jsonAssemblyPath

            #Add a binding redirect to force any additional newtonsoft loads to this version
            # [Appdomain]::CurrentDomain.Add_AssemblyResolve({
            #     param($sender,$assembly)
            #     $assemblyName = $assembly.name
            #     if ($assemblyName -match 'Newtonsoft') {
            #         return [newtonsoft.json.jsonconvert].assembly
            #     } else {
            #         return [System.AppDomain]::CurrentDomain.GetAssemblies() | where fullname -match $assemblyName
            #     }
            # })

        }
    }

    #Make sure that PSGet Beta is available
    BootstrapPSGetBeta

    #Import Prerequisites
    #To specify prerelease, you must use requiredversion and the prefix added to the modulename with '__'
    Import-PowerCDRequirement -ModuleInfo @(
        @{ModuleName='Pester__rc9';RequiredVersion='5.0.0'}
        'BuildHelpers'
        'PSScriptAnalyzer'
        #FIXME: Powerconfig doesn't work on Windows Powershell due to assembly differences
        #@{ModuleName='PowerConfig__beta0010';RequiredVersion='0.1.1'}
    )

    #Start a new PowerConfig, using PowerCDSetting as a base
    $PCDDefaultSetting = Get-PowerCDSetting

    # FIXME: Powerconfig doesn't work on Windows Powershell due to assembly differences
    # $PCDConfig = New-PowerConfig | Add-PowerConfigObject -Object $PCDDefaultSetting
    # $null = $PCDConfig | Add-PowerConfigYamlSource -Path (Join-Path $PCDDefaultSetting.BuildEnvironment.ProjectPath 'PSModule.build.settings.yml')
    # $null = $PCDConfig | Add-PowerConfigEnvironmentVariableSource -Prefix 'POWERCD_'

    #. $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Global -Option ReadOnly -Force -Value $PCDDefaultSetting

    #Test if dotnet is installed
    try {
        [Version]$dotnetVersion = (dotnet --info | where {$_ -match 'Version:'} | select -first 1).trim() -split (' +') | select -last 1
            } catch {
        throw 'PowerCD requires dotnet 3.0 or greater to be installed. Hint: https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script'
    }
    if ($dotnetVersion -lt '3.0.0') {throw "PowerCD detected dotnet $dotnetVersion but 3.0 or greater is required. Hint: https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script'"}

    # $defaultToolsFilePath = (Join-Path $pcdsetting.general.projectroot '.config/dotnet-tools.json')
    # if (-not (Test-Path $defaultToolsFilePath)) {
    #     $manifestPath = Get-ChildItem -Recurse -Path (Split-Path (Get-Module -Name 'PowerCD').path) -Include 'dotnet-tools.json'
    # }
    # if ($manifestPath) {
    #     $manifestPath = '--tool-manifest',$manifestPath
    # }
    # [String]$restoreResult = dotnet tool restore $manifestPath *>&1
    # if ($restoreResult -notmatch 'Restore was successful') {throw "Dotnet Tool Restore Failed: $restoreResult"}

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($PCDSetting.BuildEnvironment.buildsystem -and $PCDSetting.BuildEnvironment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = 'SilentlyContinue'
    }

    Write-Host -fore cyan "Done PowerCD.Initialize $([string]$bootstrapTimer.elapsed)"
}