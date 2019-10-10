function Import-PowerCDModuleFast ($ModuleName,[Switch]$Package,[Switch]$Force) {
    process {
        #Get a temporary directory
        $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(),'PowerCD',$ModuleName)
        $tempfile = join-path $tempModulePath "$ModuleName.zip"

        if ((Test-Path $tempfile) -and -not $Force) {
            Write-Verbose "$ModuleName already installed as $tempfile"
            if ($Package) {$tempModulePath}
            return
        }

        #This only happens if -Force was specified, so we require confirmation so that the user didn't do something stupid like put ../../.. in the path
        if (Test-Path $tempModulePath) {Remove-Item $tempModulePath -Recurse -Confirm:$true}

        New-Item -ItemType Directory -Path $tempModulePath > $null

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
        Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
        $GLOBAL:ProgressPreference = $CurrentProgressPreference

        $ModuleToImportPath = Join-Path $tempModulePath "$ModuleName.psd1"
        if (-not $Package) {
            write-verbose "Importing $ModuleName from $ModuleToImportPath"
            Import-Module $ModuleToImportPath -force
        } else {
            $tempModulePath
        }
    }
}