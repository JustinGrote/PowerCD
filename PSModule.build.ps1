
(gci $buildroot\PowerCD\Tasks).fullname.foreach{
    . $PSItem
}

task Init Init.PowerCD
task Clean Clean.PowerCD

task . Init,Clean