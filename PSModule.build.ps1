
(gci $buildroot\PowerCD\Tasks).fullname.foreach{
    . $PSItem
}
(gci $buildroot\PowerCD\Private).fullname.foreach{
    . $PSItem
}

task Init Init.PowerCD
task Clean Clean.PowerCD
task Version Version.PowerCD
task . Init,Clean,Version