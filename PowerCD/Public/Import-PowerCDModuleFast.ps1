function Import-PowerCDModuleFast {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String[]]$ModuleName,
        [String]$Version,
        [Switch]$Package,
        [Switch]$Force
    )
    process {
        foreach ($ModuleName in $ModuleName) {

            #Get a temporary directory
            $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(), 'PowerCD', $ModuleName)
            $ModuleManifestPath = Join-Path $tempModulePath "$ModuleName.psd1"
            $tempfile = join-path $tempModulePath "$ModuleName.zip"

            if ((Test-Path $tempModulePath) -and -not $Force) {
                Write-Verbose "$ModuleName already found in $tempModulePath"
            }
            else {
                if (Test-Path $tempModulePath) {
                    Remove-Item $tempfile -Force
                    Remove-Item $tempModulePath -Recurse -Force
                }

                New-Item -ItemType Directory -Path $tempModulePath > $null

                #Fetch and import the module
                $baseURI = 'https://powershellgallery.com/api/v2/package/'
                if ($Package) {
                    $baseURI = 'https://www.nuget.org/api/v2/package/'
                }

                if ($Version) {
                    #Ugly syntax for what is effectively "Join-Path" for URIs
                    [uri]::new([uri]$baseURI, $version)
                }
                $moduleLatestURI = "$baseURI$ModuleName"

                write-verbose "Fetching $ModuleName from $moduleLatestURI"
                (New-Object Net.WebClient).DownloadFile($moduleLatestURI, $tempfile)

                $CurrentProgressPreference = $ProgressPreference
                $GLOBAL:ProgressPreference = 'silentlycontinue'
                Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
                $GLOBAL:ProgressPreference = $CurrentProgressPreference
            }

            if (-not $Package) {
                write-verbose "Importing $ModuleName from $ModuleManifestPath and removing any existing modules with the same name"
                Get-Module $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
                Import-Module $ModuleManifestPath -force
            }
            else {
                $tempModulePath
            }
        }
    }
}