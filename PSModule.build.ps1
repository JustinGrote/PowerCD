Enter-Build {
    Import-PowerCDModuleFast BuildHelpers
    Import-Module $BuildRoot\PowerCD\PowerCD -force
    Initialize-PowerCD
}

task Clean.PowerCD {
    Invoke-PowerCDClean
}

task Version.PowerCD {
    . Get-PowerCDVersion > $null
}

task Clean Clean.PowerCD
task Version Version.PowerCD
task . Clean,Version