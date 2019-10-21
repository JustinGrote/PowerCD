function Compress-PowerCDModule {
    [CmdletBinding()]
    param(
        #Path to the directory to archive
        [Parameter(Mandatory)]$Path,
        #Output for Zip File Name
        [Parameter(Mandatory)]$Destination
    )

    $CompressArchiveParams = @{
        Path = $Path
        DestinationPath = $Destination
    }

    $CurrentProgressPreference = $GLOBAL:ProgressPreference
    $GLOBAL:ProgressPreference = 'SilentlyContinue'
    Compress-Archive @CompressArchiveParams
    $GLOBAL:ProgressPreference = $CurrentProgressPreference
    write-verbose ("Zip File Output:" + $CompressArchiveParams.DestinationPath)
}