#requires -version 5.1

#PowerCD Bootstrap
. $PSScriptRoot\PowerCD.buildinit.ps1
. PowerCD.Tasks

#region Tasks

Enter-Build {
    Initialize-PowerCD
}

task Clean PowerCD.Clean
task Build PowerCD.Build
task Package PowerCD.Package
task . PowerCD.Default