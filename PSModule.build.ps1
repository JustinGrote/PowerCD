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

task CopyFilesToBuildDir.PowerCD {
    Build-PowerCDModule
}


task Clean Clean.PowerCD
task Version Version.PowerCD
task Build CopyFilesToBuildDir.PowerCD

task . Clean,Version,Build