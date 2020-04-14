using namespace Microsoft.Powershell.Commands
using namespace System.Collections.Generic
using namespace NuGet.Versioning
function Import-PowerCDRequirement {
    <#
    .SYNOPSIS
    Installs modules from the Powershell Gallery. In the future this will support more once PSGet is more reliable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        #Specify which modules to install. If a module needs to be a prerelease, specify the prerelease tag with __ after the module name e.g. PowershellGet__beta1
        [Parameter(Mandatory, ValueFromPipeline)][ModuleSpecification[]]$ModuleInfo,
        #Where to import the PowerCD Requirement. Defaults to the PowerCD folder in LocalAppData
        $Path = (Join-Path ([io.path]::GetTempPath()) 'PowerCD')
    )
    begin {
        $modulesToInstall = [List[PSCustomObject]]@()
        #Make sure PSGet 3.0 is installed
        try {
            Get-Command 'save-psresource' -ErrorAction Stop > $null
        } catch {
            throw 'You need PowershellGet 3.0 or greater to use this command. Hint: BootstrapPSGetBeta'
        }
        function ConvertTo-NugetVersionRange ([ModuleSpecification]$ModuleSpecification) {
            try {
                #double-underscore is used as a prerelease delimiter, since ModuleSpecification doesn't currently have a prerelease field
                $preRelease = ($ModuleSpecification.Name -split '__')[1]
            } catch {
                $preRelease = $null
            }
            switch ($true) {
                ($null -ne $ModuleSpecification.RequiredVersion) {
                    if ($Prerelease) {
                        return "[$($ModuleSpecification.RequiredVersion)-$PreRelease]"
                    }
                    return "[$($ModuleSpecification.RequiredVersion)]"
                }

                ($ModuleSpecification.Version -and $ModuleSpecification.MaximumVersion) {
                    return "[$(ModuleSpecification.Version),$($ModuleSpecification.RequiredVersion)]"
                }

                ($ModuleSpecification.Version -and -not $ModuleSpecification.MaximumVersion) {
                    return [String]($ModuleSpecification.Version)
                }

                ($ModuleSpecification.MaximumVersion -and -not $ModuleSpecification.Version) {
                    return "(,$($ModuleSpecification.Version)]"
                }
            }
        }
    }

    process {
        foreach ($ModuleInfoItem in $ModuleInfo) {
            $PSResourceParams = [Ordered]@{
                Name                = $ModuleInfoItem.Name.split('__')[0]
                IncludeDependencies = $true
            }
            $moduleVersion = ConvertTo-NugetVersionRange $ModuleInfoItem
            if ($ModuleVersion) { $PSResourceParams.Version = $ModuleVersion }
            [Bool]$IsPrerelease = try {
                [Bool](([NugetVersion]($ModuleVersion -replace '[\[\]]','')).IsPrerelease)
            } catch {
                $false
            }

            try {
                $modulesToInstall.Add((Find-PSResource @PSResourceParams -Prerelease:$IsPrerelease -ErrorAction Stop))
            } catch [NullReferenceException] {
                Write-Warning "Found nothing on the powershell gallery for $($PSResourceParams.Name) $($PSResourceParams.Version)"
            }
        }
    }

    end {
        foreach ($moduleItem in ($modulesToInstall | Sort-Object -Property Name,Version -Unique)) {
            $ModuleManifestPath = [IO.Path]::Combine($Path, $moduleItem.Name, $ModuleItem.Version, "$($ModuleItem.Name).psd1")

            #Check for the module existence in an efficient manner
            $moduleExists = if (Test-Path $ModuleManifestPath) {
                if ($moduleItem.Version.IsPrerelease) {
                    ((Import-PowershellDataFile $ModuleManifestPath).privatedata.psdata.prerelease -eq $moduleItem.Version.Release)
                } else {
                    $true
                }
            } else {$false}
            if ($moduleExists) {
                Write-Verbose "Module $($ModuleItem.Name) $($ModuleItem.Version) already installed. Skipping..."
            } else {
                if ($PSCmdlet.ShouldProcess($Path,"Installing PowerCD Requirement $($ModuleItem.Name) $($ModuleItem.Version)")) {
                    try {
                        Save-PSResource -Path $Path -Name $ModuleItem.Name -Version $ModuleItem.Version -Prerelease:$isPrerelease -ErrorAction Stop
                    } catch [IO.IOException] {
                        if ([string]$PSItem -match 'Cannot create a file when that file already exists') {
                            Write-Warning "Module $($ModuleItem.Name) $($ModuleItem.Version) already exists. This is probably a bug because the manifest wasn't detected. Skipping..."
                        } else {
                            throw $PSItem
                        }
                    }
                }
            }
            Import-Module -ErrorAction Stop $ModuleManifestPath
        }
    }
    #Use this for Save-Module




    # }
    # process { foreach ($ModuleName in $ModuleName) {
    #     #Get a temporary directory
    #     $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(), 'PowerCD', $ModuleName)
    #     $ModuleManifestPath = Join-Path $tempModulePath "$ModuleName.psd1"
    #     $tempfile = join-path $tempModulePath "$ModuleName.zip"

    #     if ((Test-Path $ModuleManifestPath) -and -not $Force) {
    #         if ($Version) {

    #         }
    #         Write-Verbose "$ModuleName already found in $tempModulePath"
    #         continue
    #     }

    #     New-Item -ItemType Directory -Path $tempModulePath > $null

    #     #Fetch and import the module
    #     [uri]$baseURI = 'https://powershellgallery.com/api/v2/package/'
    #     if ($Package) {
    #         [uri]$baseURI = 'https://www.nuget.org/api/v2/package/'
    #     }

    #     [uri]$moduleURI = [uri]::new($baseURI, "$ModuleName/")

    #     if ($Version) {
    #         #Ugly syntax for what is effectively "Join-Path" for URIs
    #         $moduleURI = [uri]::new($moduleURI,"$version/")
    #     }

    #     Write-Verbose "Fetching $ModuleName from $moduleURI"
    #     (New-Object Net.WebClient).DownloadFile($moduleURI, $tempfile)
    #     if ($PSEdition -eq 'Core') {
    #         #Newer overwrite extraction method
    #         [System.io.Compression.ZipFile]::ExtractToDirectory(
    #             [String]$tempfile,          #sourceArchiveFileName
    #             [String]$tempModulePath,    #destinationDirectoryName
    #             [bool]$true                 #overwriteFiles
    #         )
    #     } else {
    #         #Legacy behavior
    #         Remove-Item $tempModulePath/* -Recurse -Force
    #         [ZipFile]::ExtractToDirectory($tempfile, $tempModulePath)
    #     }

    #     if (-not (Test-Path $ModuleManifestPath)) {throw "Installation of $ModuleName failed"}

    #     Import-Module $ModuleManifestPath -Force -Scope Global 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose

    # }} #Process foreach
}