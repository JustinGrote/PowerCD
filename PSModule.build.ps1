#requires -version 5.1

#PowerCD Bootstrap
. $PSScriptRoot\PowerCD.buildinit.ps1

#Bootstrap package management in a new process. If you try to do it same-process you can't import it because the DLL from the old version is already loaded
#YOU MUST DO THIS IN A NEW SESSION PRIOR TO RUNNING ANY PACKAGEMANGEMENT OR POWERSHELLGET COMMANDS
#NOTES: Tried using a runspace but install-module would crap out on older PS5.x versions.

# function BootstrapPSGet {
#     $psGetVersionMinimum = '2.2.1'
#     $PowershellGetModules = get-module PowershellGet -listavailable | where version -ge $psGetVersionMinimum
#     if ($PowershellGetModules) {
#         write-verbose "PowershellGet $psGetVersionMinimum found. Skipping bootstrap..."
#         return
#     }

#     write-verbose "PowershellGet $psGetVersionMinimum not detected. Bootstrapping..."
#     Start-Job -Verbose -Name "BootStrapPSGet" {
#         $psGetVersionMinimum = '2.2.1'
#         $progresspreference = 'silentlycontinue'
#         Install-Module PowershellGet -MinimumVersion $psGetVersionMinimum -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
#     } | Receive-Job -Wait -Verbose
#     Remove-Job -Name "BootStrapPSGet"
#     Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop
# }
# BootStrapPSGet

# Import-Module PowershellGet -Scope Global -Force -MinimumVersion 2.2 -ErrorAction Stop

#endregion Bootstrap

. PowerCD.Tasks


#region Tasks

Enter-Build {
    Initialize-PowerCD
}

task Clean PowerCD.Clean
task Build PowerCD.Build
task Package PowerCD.Package
task . PowerCD.Default