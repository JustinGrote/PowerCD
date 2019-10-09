function FastImportModule ($ModuleName,[Switch]$Package) {
    process {
        #Get a temporary directory
        $tempFilePath = [System.IO.Path]::GetTempFileName()
        $tempdir = $tempFilePath -replace '\.tmp$',''
        $tempFile = "$tempdir.zip"

        #Fetch and import the module
        $baseURI = 'https://powershellgallery.com/api/v2/package/'
        if ($Package) {
            $baseURI = 'https://www.nuget.org/api/v2/package/'
        }
        $moduleLatestURI = "$baseURI$ModuleName"

        write-verbose "Fetching $ModuleName from $moduleLatestURI"
        (New-Object Net.WebClient).DownloadFile($moduleLatestURI, $tempfile)

        $CurrentProgressPreference = $ProgressPreference
        $GLOBAL:ProgressPreference = 'silentlycontinue'
        Expand-Archive $tempfile $tempdir -Force -ErrorAction stop
        $GLOBAL:ProgressPreference = $CurrentProgressPreference

        $ModuleToImportPath = Join-Path $tempdir "$ModuleName.psd1"
        if (-not $Package) {
            write-verbose "Importing $ModuleName from $ModuleToImportPath"
            Import-Module $ModuleToImportPath -force
        } else {
            $tempdir
        }
    }
}