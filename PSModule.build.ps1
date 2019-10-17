
. $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
Import-PowerCDModuleFast BuildHelpers
Import-PowerCDModuleFast Pester
Import-PowerCDModuleFast PackageManagement
Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue -verbose
. PowerCD.Tasks

Enter-Build {
    #Bootstrap BuildHelpers Module
    #TODO: Don't do this step in production buildhelpers, it should be a nestedmodule

    Initialize-PowerCD
}

#TODO: Make task for this
task CopyBuildTasksFile {
    Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0] -verbose
}


task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,CopyBuildTasksFile
task Test TestPester.PowerCD


task . Clean,Build,Test
