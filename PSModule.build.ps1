
(gci $buildroot\PowerCD\Tasks).fullname.foreach{
    . $PSItem
}
(gci $buildroot\PowerCD\Private).fullname.foreach{
    . $PSItem
}

Enter-Build {
    . $BuildRoot\PowerCD\Public\Initialize-PowerCD.ps1
    Initialize-PowerCD
    (gci $buildroot\PowerCD\Public).fullname.foreach{
        . $PSItem
    }
}

task Clean Clean.PowerCD
task Version Version.PowerCD
task . Clean,Version