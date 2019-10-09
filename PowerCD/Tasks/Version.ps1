task Version.PowerCD {
    #FIXME: Remove after I get the function bootstrapping sorted out
    (gci $buildroot\PowerCD\Public).fullname.foreach{
        . $PSItem
    }

    Get-PowerCDVersion
}