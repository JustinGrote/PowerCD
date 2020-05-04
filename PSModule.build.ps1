#requires -version 5.1

#PowerCD Bootstrap
$GLOBAL:ProgressPreference = 'SilentlyContinue'
. $PSScriptRoot\PowerCD.bootstrap.ps1


Enter-Build {
    Initialize-PowerCD
}

. PowerCD.Tasks


task Clean PowerCD.Clean
task Build PowerCD.Build
task Package PowerCD.Package
task . PowerCD.Default