Enter-Build {
    Import-Module $BuildRoot\PowerCD\PowerCD -Force -WarningAction SilentlyContinue
    Import-PowerCDModuleFast BuildHelpers
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