(gci C:\Users\JGrote\Documents\Github\PowerCD\PowerCD\Tasks).foreach{
    . $PSItem.fullname
}

task Init Init.PowerCD
task Clean Clean.PowerCD

task . Init,Clean