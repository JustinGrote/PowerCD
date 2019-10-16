
Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue -verbose
. PowerCD.Tasks

Enter-Build {
    #Bootstrap BuildHelpers Module
    #TODO: Don't do this step in production buildhelpers, it should be a nestedmodule
    . $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
    Import-PowerCDModuleFast BuildHelpers
    Import-PowerCDModuleFast Pester
    Initialize-PowerCD
}

task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD
task Test TestPester.PowerCD
task . Clean,Build,Test