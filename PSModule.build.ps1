#requires -version 5.1

#region PowerCDBootstrap
#. ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap')))
. $PSScriptRoot\PowerCD\PowerCD.bootstrap.ps1
#endregion PowerCDBootstrap

task PowerCD.CopyPowerCDConfigFiles -After PowerCD.BuildPSModule {
    if (Test-Path $BuildRoot\BuildOutput\PowerCD) {
        @(
            ".config\dotnet-tools.json",
            "GitVersion.yml",
            "PowerCD\PowerCD.bootstrap.ps1",
            "PowerCD\PowerCD.tasks.ps1"
            "Tests\00_PSModule.tests.ps1"
        ).foreach{
            $sourceItem = Join-Path $BuildRoot $PSItem
            if (Test-Path $sourceItem) {
                Copy-Item $sourceItem -Destination (Get-Item $BuildRoot\BuildOutput\PowerCD)
            }
        }
    }
}