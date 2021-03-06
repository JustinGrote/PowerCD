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
        $Path = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PowerCD')
    )
    begin {
        $modulesToInstall = [List[PSCustomObject]]@()

        #Make sure PSGet 3.0 is installed
        try {
            #This is an indirect way to load the nuget assemblies to get the NugetVersion type added to the session
            [Void](Get-PSResource -Name 'DummyModule')
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
                    return "[$(ModuleSpecification.Version),$($ModuleSpecification.MaximumVersion)]"
                }

                ($ModuleSpecification.Version -and -not $ModuleSpecification.MaximumVersion) {
                    return [String]($ModuleSpecification.Version)
                }

                ($ModuleSpecification.MaximumVersion -and -not $ModuleSpecification.Version) {
                    return "(,$($ModuleSpecification.MaximumVersion)]"
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
            if (Get-Module -FullyQualifiedName $ModuleInfoItem) {
                Write-Verbose "Module $(($ModuleInfoItem.Name,$ModuleInfoItem.Version -join ' ').trim()) is currently loaded. Skipping..."
                continue
            }
            $moduleVersion = ConvertTo-NugetVersionRange $ModuleInfoItem
            if ($ModuleVersion) { $PSResourceParams.Version = $ModuleVersion }

            [Bool]$IsPrerelease = try {
                [Bool](([NugetVersion]($ModuleVersion -replace '[\[\]]','')).IsPrerelease)
            } catch {
                $false
            }

            try {
                #TODO: Once PSGetv3 Folders are more stable, do a local check for the resource with PSModulePath first
                $modulesToInstall.Add((Find-PSResource @PSResourceParams -Prerelease:$IsPrerelease -ErrorAction Stop))
            } catch [NullReferenceException] {
                Write-Warning "Found nothing on the powershell gallery for $($PSResourceParams.Name) $($PSResourceParams.Version)"
            }
        }
    }

    end {
        foreach ($moduleItem in ($modulesToInstall | Sort-Object -Property Name,Version -Unique)) {
            $ModuleManifestPath = [IO.Path]::Combine($Path, $moduleItem.Name, $ModuleItem.Version, "$($ModuleItem.Name).psd1")
            $IsPrerelease = $moduleItem.Version.IsPrerelease
            #Check for the module existence in an efficient manner
            $moduleExists = if (Test-Path $ModuleManifestPath) {
                if ($IsPrerelease) {
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
                        if ($isLinux) {
                            #FIXME: Remove after https://github.com/PowerShell/PowerShellGet/issues/123 is closed
                            Save-Module -RequiredVersion $ModuleItem.Version -Name $ModuleItem.Name -Path $Path -Force -AllowPrerelease:$IsPrerelease -ErrorAction Stop
                            #Save-Module doesn't save with the prelease tag name, so we need to import via the non-prerelease version folder instead
                            $ModuleManifestPath = [IO.Path]::Combine($Path, $moduleItem.Name, $ModuleItem.Version.Version.ToString(3), "$($ModuleItem.Name).psd1")
                        } else {
                            Save-PSResource -Path $Path -Name $ModuleItem.Name -Version "[$($ModuleItem.Version)]" -Prerelease:$IsPrerelease -ErrorAction Stop
                        }
                    } catch [IO.IOException] {
                        if ([string]$PSItem -match 'Cannot create a file when that file already exists') {
                            Write-Warning "Module $($ModuleItem.Name) $($ModuleItem.Version) already exists. This is probably a bug because the manifest wasn't detected. Skipping..."
                        } else {
                            throw $PSItem
                        }
                    }
                }
            }

            try {
                #Only try to import if not already loaded, speeds up repeat attempts
                if (-not (Get-Module $ModuleItem.Name).Path -eq ($ModuleManifestPath -replace 'psd1$','psm1')) {
                    Import-Module $ModuleManifestPath -Global -ErrorAction Stop -Verbose:$false > $null
                }
            } catch {
                $caughtError = $PSItem
                #Catch common issues
                switch -regex ([String]$PSItem) {
                    'Error in TypeData "Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.RuleInfo"' {
                        throw [InvalidOperationException]'Detected an incompatible PSScriptAnalyzer was already loaded. Please restart your Powershell session.'
                    }
                    'assertion operator .+ has been added multiple times' {
                        throw [InvalidOperationException]'Detected an incompatible Pester was already loaded. Please restart your Powershell session.'
                    }
                    default {
                        throw $CaughtError.Exception
                    }
                }
            }
        }
        #Pester 5 check
        if (-not (Get-Module -FullyQualifiedName @{ModuleName='Pester';ModuleVersion='4.9999'})) {
            throw 'A loaded Pester version less than 5.0 was detected. Please restart your Powershell session'
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