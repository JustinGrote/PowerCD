Enter-Build {
    Import-PowerCDModuleFast BuildHelpers
    Import-PowerCDModuleFast PowershellBuild
    Import-Module $BuildRoot\PowerCD\PowerCD -force
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