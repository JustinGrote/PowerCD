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

    #Fix a module import bug if powershell was started from pwsh. This is fixed in PWSH7 and should do nothing
    Reset-WinPSModules

    #PS5.1: Load a fairly new version of newtonsoft.json to maintain compatibility with other tools, if not present
    if ($PSEdition -eq 'Desktop') {
        [bool]$newtonsoftJsonLoaded = try {
            [bool]([newtonsoft.json.jsonconvert].assembly)
        } catch {
            $false
        }
        if (-not $NewtonsoftJsonLoaded) {
            Write-Verbose "Bootstrapping Newtonsoft.Json for Windows Powershell"
            $jsonAssemblyPath = "$PSSCRIPTROOT/../lib/Newtonsoft.Json.dll"
            if ($PowerCDMetaBuild) {
                #Move the DLL to the localappdata folder to prevent an issue with zipping up the completed build
                $tempJsonAssemblyPath = Join-Path ([Environment]::GetFolderpath('LocalApplicationData')) 'PowerCD/Newtonsoft.Json.dll'
                Move-Item $jsonAssemblyPath $tempJsonAssemblyPath
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
    Import-PowerCDRequirement -Verbose -ModuleInfo @(
        'Pester'
        'BuildHelpers'
        'PSScriptAnalyzer'
        #FIXME: Powwerconfig doesn't work on Windows Powershell due to assembly differences
        #@{ModuleName='PowerConfig__beta0010';RequiredVersion='0.1.1'}
    )

    #Test if dotnet is installed
    try {
        [Version]$dotnetVersion = (dotnet --info | where {$_ -match 'Version:'} | select -first 1).trim() -split (' +') | select -last 1
            } catch {
        throw 'PowerCD requires dotnet 3.0 or greater to be installed. Hint: https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script'
    }
    if ($dotnetVersion -lt '3.0.0') {throw "PowerCD detected dotnet $dotnetVersion but 3.0 or greater is required. Hint: https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script'"}

    [String]$restoreResult = dotnet tool restore *>&1
    if ($restoreResult -notmatch 'Restore was successful') {throw "Dotnet Tool Restore Failed: $restoreResult"}

    #Start a new PowerConfig, using PowerCDSetting as a base
    $PCDDefaultSetting = Get-PowerCDSetting

    # FIXME: Powerconfig doesn't work on Windows Powershell due to assembly differences
    # $PCDConfig = New-PowerConfig | Add-PowerConfigObject -Object $PCDDefaultSetting
    # $null = $PCDConfig | Add-PowerConfigYamlSource -Path (Join-Path $PCDDefaultSetting.BuildEnvironment.ProjectPath 'PSModule.build.settings.yml')
    # $null = $PCDConfig | Add-PowerConfigEnvironmentVariableSource -Prefix 'POWERCD_'

    #. $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Global -Option ReadOnly -Force -Value $PCDDefaultSetting

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($PCDSetting.BuildEnvironment.buildsystem -and $PCDSetting.BuildEnvironment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = "SilentlyContinue"
    }
}
