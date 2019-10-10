Enter-Build {
    #Bootstrap BuildHelpers Module
    #TODO: Don't do this step in production buildhelpers, it should be a nestedmodule
    . $BuildRoot\PowerCD\Public\Import-PowerCDModuleFast.ps1
    Import-PowerCDModuleFast BuildHelpers
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

task Clean Clean.PowerCD
task Version Version.PowerCD
task Build BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD

task . Clean,Version,Build