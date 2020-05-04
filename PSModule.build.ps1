#requires -version 5.1

#PowerCD Bootstrap
$GLOBAL:ProgressPreference = 'SilentlyContinue'
. $PSScriptRoot\PowerCD.bootstrap.ps1


Enter-Build {
    Initialize-PowerCD
}

. PowerCD.Tasks

task PowerCD.Test.Pester {
    Invoke-Pester
}

task Clean PowerCD.Clean
task Build PowerCD.Build
task Test PowerCD.Test
task Package PowerCD.Package
task . PowerCD.Default