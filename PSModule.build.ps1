#requires -version 5.1

#PowerCD Bootstrap
. $PSScriptRoot\PowerCD.buildinit.ps1
. PowerCD.Tasks

#region Tasks

Enter-Build {
    Write-Host -fore cyan "Task PowerCD.Initialize"
    $bootstrapTimer = [Diagnostics.Stopwatch]::StartNew()
    Initialize-PowerCD
    Write-Host -fore cyan "Done PowerCD.Initialize $([string]$bootstrapTimer.elapsed)"
}

task Clean PowerCD.Clean
task Build PowerCD.Build
task Package PowerCD.Package
task . PowerCD.Default