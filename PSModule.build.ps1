param(
    $Settings =
)


. $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
Import-PowerCDModuleFast BuildHelpers
Import-PowerCDModuleFast Pester
Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue
. PowerCD.Tasks

Enter-Build {
    #Bootstrap BuildHelpers Module
    #TODO: Don't do this step in production buildhelpers, it should be a nestedmodule

    Initialize-PowerCD

    #Fix a bug in case powershell was started in pwsh: https://github.com/PowerShell/PowerShell/issues/9957
    if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
        Write-Warning 'Powershell 5.1 was started inside of pwsh, reinitializing Microsoft.Powershell.Utility'
        $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
            Where-Object Version -lt 6.0.0 |
            Sort-Object Version -Descending |
            Select-Object -First 1
        Remove-Module 'Microsoft.Powershell.Utility'
        Import-Module $ModuleToImport -Force
    }
}

#TODO: Make task for this
task CopyBuildTasksFile {
    Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0] -verbose
}


task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,CopyBuildTasksFile
task Test TestPester.PowerCD
task . Clean,Build,Test