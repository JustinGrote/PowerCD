#requires -version 5.1

#region Bootstrap
#Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
    Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
    $env:PSModulePath = ($env:PSModulePath -split [io.path]::PathSeparator | where {$_ -match 'WindowsPowershell'}) -join [io.path]::PathSeparator
    $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
        Where-Object Version -lt 6.0.0 |
        Sort-Object Version -Descending |
        Select-Object -First 1
    Remove-Module 'Microsoft.Powershell.Utility'
    Import-Module $ModuleToImport -Force
}


#Bootstrap package management in a new process. If you try to do it same-process you can't import it because the DLL from the old version is already loaded
#YOU MUST DO THIS IN A NEW SESSION PRIOR TO RUNNING ANY PACKAGEMANGEMENT OR POWERSHELLGET COMMANDS
#NOTES: Tried using a runspace but install-module would crap out on older PS5.x versions.
function BootstrapPSGet {
    $psGetVersionMinimum = '2.2.1'
    $PowershellGetModules = get-module PowershellGet -listavailable | where version -ge $psGetVersionMinimum
    if ($PowershellGetModules) {
        write-verbose "PowershellGet $psGetVersionMinimum found. Skipping bootstrap..."
        return
    }

    write-verbose "PowershellGet $psGetVersionMinimum not detected. Bootstrapping..."
    Start-Job -Verbose -Name "BootStrapPSGet" {
        $psGetVersionMinimum = '2.2.1'
        $progresspreference = 'silentlycontinue'
        Install-Module PowershellGet -MinimumVersion $psGetVersionMinimum -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
    } | Receive-Job -Wait -Verbose
    Remove-Job -Name "BootStrapPSGet"
    Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop
}
BootStrapPSGet
Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop

#endregion Bootstrap
Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue
. PowerCD.Tasks
gmo Pester -ListAvailable | Out-String | Out-Warning
Import-PowerCDRequirement @(
    'Pester'
    'BuildHelpers'
    'PSScriptAnalyzer'
)

#region Tasks

Enter-Build {
    Initialize-PowerCD
}

task Clean Clean.PowerCD
task Build Build.PowerCD
task Package Package.PowerCD
task Test Test.PowerCD
task . Clean,Build,Test,Package