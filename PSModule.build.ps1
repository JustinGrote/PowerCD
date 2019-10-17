# param(
#     $Settings =
# )


. $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
Import-PowerCDModuleFast BuildHelpers
Import-PowerCDModuleFast Pester
Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue
. PowerCD.Tasks

Enter-Build {

    #Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
    if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
        Write-Verbose 'Powershell 5.1 was started inside of pwsh, reinitializing Microsoft.Powershell.Utility'
        $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
            Where-Object Version -lt 6.0.0 |
            Sort-Object Version -Descending |
            Select-Object -First 1
        Remove-Module 'Microsoft.Powershell.Utility'
        Import-Module $ModuleToImport -Force
    }

    Initialize-PowerCD

}

#TODO: Make task for this
task CopyBuildTasksFile {
    Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0]
}

task PackageZip {

    [String]$ZipFileName = $PCDSetting.BuildEnvironment.ProjectName + '-' + $PCDSetting.VersionLabel + '.zip'
    $CompressArchiveParams = @{
        Path = $PCDSetting.BuildEnvironment.ModulePath
        DestinationPath = join-path $PCDSetting.BuildEnvironment.BuildOutput $ZipFileName
    }
    Compress-Archive @CompressArchiveParams
    write-verbose ("Zip File Output:" + $CompressArchiveParams.DestinationPath)

}


task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,CopyBuildTasksFile
task Package PackageZip
task Test TestPester.PowerCD
task . Clean,Build,Test,Package