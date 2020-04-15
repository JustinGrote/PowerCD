using namespace System.IO.Compression
function BootstrapPSGetBeta {
    #PowerCD Module Directory for builds
    $SCRIPT:powercdModulePath = Join-Path ([io.path]::GetTempPath()) 'PowerCD'

    #Fetch PowerShellGet 3.0+ if not already present. We use this instead of Save-Module to avoid
    #loading the builtin version of PowershellGet

    #This is a temporary "fast fetch" for latest version of PowershellGet
    $moduleInfo = (Invoke-RestMethod -UseBasicParsing 'https://www.powershellgallery.com/api/v2/Packages?$filter=Id%20eq%20%27PowershellGet%27%20and%20Version%20ge%20%273.0.0%27%20and%20IsPrerelease%20eq%20true&$orderby=Version%20desc&$top=1&$select=Id,Version,NormalizedVersion')
    $moduleVersion = $moduleInfo.properties.NormalizedVersion
    $moduleUri = $moduleInfo.content.src
    $psgetModulePath = Join-Path $powercdModulePath 'PowershellGet'
    $moduleManifestPath = [IO.Path]::Combine($psGetModulePath, $moduleVersion, 'PowershellGet.psd1')

    if (-not (Test-Path $ModuleManifestPath)) {
        Write-Verbose "Latest PowershellGet Not Found, Installing $moduleVersion..."
        if (Test-Path $psgetModulePath) {Remove-Item $psGetModulePath -recurse -force}
        $psGetZipPath = join-path $powercdModulePath "PowershellGet.zip"
        New-Item -ItemType Directory -Path $powercdModulePath -Force > $null
        (New-Object Net.WebClient).DownloadFile($moduleURI, $psGetZipPath) > $null

        #Required due to a quirk in Windows Powershell 5.1: https://stackoverflow.com/questions/29007742/unable-to-use-system-io-compression-filesystem-dll/29022092

        #FIXME: Remove Debug
        # Add-Type -AssemblyName mscorlib
        # Add-Type -assembly "System.IO.Compression.Filesystem"
        # Add-Type -assembly "System.IO.Compression"
        Write-Verbose ([System.IO.Compression.ZipFile].assembly)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($psGetZipPath, (Split-Path $ModuleManifestPath)) > $null
        Import-Module -Force $moduleManifestPath -Scope Global -ErrorAction Stop


        #Register Powershell Gallery if not present
        try {
            if (-not (Get-PSResourceRepository -Name psgallery)) {
                Register-PSResourceRepository -PSGallery -Trusted
            }
        } catch [ArgumentException] {
            if ([String]$PSItem -match 'not able to successfully find xml') {
                Register-PSResourceRepository -PSGallery -Trusted
            }
        }

    }

    Write-Verbose "PowershellGet $moduleVersion found at $moduleManifestPath"
}