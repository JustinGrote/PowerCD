
(gci $buildroot\PowerCD\Tasks).fullname.foreach{
    write-host -fore magenta $PSItem
    . $PSItem
}

Enter-Build {
    (gci $buildroot\PowerCD\Public).fullname.foreach{
        write-host -fore magenta $PSItem
        . $PSItem
    }
}

task Init Init.PowerCD
task Clean Clean.PowerCD

task . Init,Clean