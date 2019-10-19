
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

            if ((Test-Path $tempfile) -and -not $Force) {
                Write-Verbose "$ModuleName already found in $tempModulePath"
            }
            else {
                if (Test-Path $tempModulePath) {
                    Remove-Item $tempfile -Force
                    Remove-Item $tempModulePath -Recurse -Force
                }

                New-Item -ItemType Directory -Path $tempModulePath > $null

                #Fetch and import the module
                [uri]$baseURI = 'https://powershellgallery.com/api/v2/package/'
                if ($Package) {
                    [uri]$baseURI = 'https://www.nuget.org/api/v2/package/'
                }

                [uri]$moduleURI = [uri]::new($baseURI, "$ModuleName/")

                if ($Version) {
                    #Ugly syntax for what is effectively "Join-Path" for URIs
                    $moduleURI = [uri]::new($moduleURI,"$version/")
                }

                Write-Verbose "Fetching $ModuleName from $moduleURI"
                (New-Object Net.WebClient).DownloadFile($moduleURI, $tempfile)

                $CurrentProgressPreference = $ProgressPreference
                $GLOBAL:ProgressPreference = 'silentlycontinue'
                Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
                $GLOBAL:ProgressPreference = $CurrentProgressPreference
            }

            if (-not $Package) {
                write-verbose "Importing $ModuleName from $ModuleManifestPath"
                Import-Module $ModuleManifestPath -force
            }
            else {
                $tempModulePath
            }
        }
    }
}