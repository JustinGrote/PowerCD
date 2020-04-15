#requires -version 5.1

#PowerCD Bootstrap

. $PSScriptRoot\PowerCD.buildinit.ps1

task Clean PowerCD.Clean
task Build PowerCD.Build
task Package PowerCD.Package
task . PowerCD.Default