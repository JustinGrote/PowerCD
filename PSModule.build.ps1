Enter-Build {
    #Bootstrap BuildHelpers Module
    #TODO: Don't do this step in production buildhelpers, it should be a nestedmodule
    . $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
    Import-PowerCDModuleFast BuildHelpers
    Import-PowerCDModuleFast Pester
    Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue
    Initialize-PowerCD
}

task Clean.PowerCD {
    Invoke-PowerCDClean
}

task Version.PowerCD {
    . Get-PowerCDVersion > $null
}

task BuildPSModule.PowerCD {
    Build-PowerCDModule
}

task SetPSModuleVersion.PowerCD {
    Set-PowerCDVersion
}

task UpdatePSModulePublicFunctions.PowerCD {
    Update-PowerCDPublicFunctions
}

task TestPester.PowerCD {
    Test-PowerCDPester
}

task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD
task Test TestPester.PowerCD

task . Clean,Build,Test