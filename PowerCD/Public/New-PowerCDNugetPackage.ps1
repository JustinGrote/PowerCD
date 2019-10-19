function New-PowerCDNugetPackage {
    [CmdletBinding()]
    param (
        #Path to the module to build
        [Parameter(Mandatory)][IO.FileInfo]$Path,
        #Where to output the new module package. Specify a folder
        [Parameter(Mandatory)][IO.DirectoryInfo]$Destination
    )

    $ModuleManifest = Get-Item $Path/*.psd1 | where {(Get-Content -Raw $PSItem) -match "ModuleVersion ?= ?\'.+\'"} | Select -First 1
    if (-not $ModuleManifest) {throw "No module manifest found in $Path. Please ensure a powershell module is present in this directory."}
    $ModuleName = $ModuleManifest.basename

    #TODO: Get this to work with older packagemanagement
    # $ModuleMetadata = Import-PowerShellDataFile $ModuleManifest

    # #Use some PowershellGet private methods to create a nuspec file and create a nupkg. This is much faster than the "slow" method referenced below
    # $NewNuSpecFileParams = @{
    #     OutputPath = $Path
    #     Id = $ModuleName
    #     Version = ($ModuleMetaData.ModuleVersion,$ModuleMetaData.PrivateData.PSData.Prerelease -join '-')
    #     Description = $ModuleMetaData.Description
    #     Authors = $ModuleMetaData.Author
    # }

    # #Fast Method but skips some metadata. Doesn't matter for non-powershell gallery publishes
    # #TODO: Add all the metadata from the publish process
    # $NuSpecPath = & (Get-Module PowershellGet) New-NuSpecFile @NewNuSpecFileParams
    # #$DotNetCommandPath = & (Get-Module PowershellGet) {$DotnetCommandPath}
    # #$NugetExePath = & (Get-Module PowershellGet) {$NugetExePath}
    # $NugetExePath = (command nuget -All -erroraction stop | where name -match 'nuget(.exe)?$').Source
    # $NewNugetPackageParams = @{
    #     NuSpecPath = $NuSpecPath
    #     NuGetPackageRoot = $Destination
    # }

    # if ($DotNetCommandPath) {
    #     $NewNugetPackageParams.UseDotNetCli = $true
    # } elseif ($NugetExePath) {
    #     $NewNugetPackageParams.NugetExePath = $NuGetExePath
    # }else {
    #     throw "Neither nuget or dotnet was detected by PowershellGet. Please check you have one or the other installed."
    # }

    # $nuGetPackagePath = & (Get-Module PowershellGet) New-NugetPackage @NewNugetPackageParams
    # write-verbose "Created NuGet Package at $nuGetPackagePath"
    # #Slow Method, maybe fallback to this
    # #Creates a temporary repository and registers it, uses publish-module which results in a nuget package

    try {
        $SCRIPT:tempRepositoryName = "$ModuleName-build-$(get-date -format 'yyyyMMdd-hhmmss')"
        Unregister-PSRepository -Name $tempRepositoryName -ErrorAction SilentlyContinue
        Register-PSRepository -Name $tempRepositoryName -SourceLocation ([String]$Destination)
        If (Get-Item -ErrorAction SilentlyContinue (join-path $Path "$ModuleName*.nupkg")) {
            Write-Build Green "Nuget Package for $ModuleName already generated. Skipping. Delete the package to retry"
        } else {
            $CurrentProgressPreference = $GLOBAL:ProgressPreference
            $GLOBAL:ProgressPreference = 'SilentlyContinue'
            Publish-Module -Repository $tempRepositoryName -Path $Path -Force
            $GLOBAL:ProgressPreference = $CurrentProgressPreference
        }
    }
    catch {Write-Error $PSItem}
    finally {
        Unregister-PSRepository $tempRepositoryName
    }
}