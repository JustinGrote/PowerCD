function GenerateAzDevopsMatrix {
    $os = @(
        'windows-latest'
        'vs2017-win2016'
        'ubuntu-latest'
        'macOS-latest'
    )

    $psversion = @(
        'pwsh'
        'powershell'
    )

    $exclude = 'ubuntu-latest-powershell','macOS-latest-powershell'

    $entries = @{}
    foreach ($osItem in $os) {
        foreach ($psverItem in $psversion) {
            $entries."$osItem-$psverItem" = @{os=$osItem;psversion=$psverItem}
        }
    }

    $exclude.foreach{
        $entries.Remove($PSItem)
    }

    $entries.keys | sort | foreach {
        "      $PSItem`:"
        "        os: $($entries[$PSItem].os)"
        "        psversion: $($entries[$PSItem].psversion)"
    }

}

