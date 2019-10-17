using namespace System.IO.Path
<#
.SYNOPSIS
Retrieves the dotnet dependencies for a powershell module
.NOTES
This process basically builds a C# Powershell Standard Library and identifies the resulting assemblies. There is probably a more lightweight way to do this.
.EXAMPLE
Get-PSModuleNugetDependencies @{'System.Text.Json'='4.6.0'}
#>
function Get-PSModuleNugetDependencies {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='String')]
    param (
        #A list of nuget packages to include. You can specify a nuget-style version with a / separator e.g. yamldotnet/3.2.*
        [Parameter(ParameterSetName='String',Mandatory,Position=0)][String[]]$PackageName,
        #Which packages and their associated versions to include, in hashtable form. Supports Nuget Versioning: https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards
        [Parameter(ParameterSetName='Hashtable',Mandatory,Position=0)][HashTable]$Packages,
        #Which .NET Framework target to use. Defaults to .NET Standard 2.0 and is what you should use for PS5+ compatible modules
        [String]$Target = 'netstandard2.0',
        #Full name of the target framework, used for fetching the JSON-formatted dependencies TODO: Resolve this
        [String]$TargetFullName = '.NETStandard,Version=v2.0',
        #Where to output the resultant assembly files. Default is a new folder 'lib' in the current directory.
        [Parameter(Position=1)][String]$Destination,
        #Which PS Standard library to use. Defaults to 5.1.0.
        [String]$PowershellTarget = '5.1.0',
        [String]$BuildPath = (Join-Path ([io.path]::GetTempPath()) 'PSModuleDeps'),
        #Name of the build project. You normally don't need to change this.
        [String]$BuildProjectName = 'PSModuleDeps',
        #Whether to output the resultant copied file paths
        [Switch]$PassThru
    )

    if ($PSCmdlet.ParameterSetName -eq 'String') {
        $Packages = @{}
        $PackageName.Foreach{
            $PackageVersion = $PSItem -split '/'
            if ($PackageVersion.count -eq 2) {
                $Packages[$PackageVersion[0]] = $PackageVersion[1]
            } else {
                $Packages[$PSItem] = '*'
            }
        }
    }

    #Add Powershell Standard Library
    $Packages['PowerShellStandard.Library'] = '5.1.0'

    if (-not ([version](dotnet --version) -ge 2.2)) {throw 'dotnet 2.2 or later is required. Make sure you have the .net core SDK 2.x+ installed'}

    #Add starter Project for netstandard 2.0
    $BuildProjectFile = Join-Path $BuildPath "$BuildProjectName.csproj"
    New-Item -ItemType Directory $BuildPath -Force > $null
@"
<Project Sdk="Microsoft.NET.Sdk">

<PropertyGroup>
    <TargetFramework>$Target</TargetFramework>
</PropertyGroup>
<ItemGroup>
<PackageReference Include="PowerShellStandard.Library" Version="$PowerShellTarget">
  <PrivateAssets>All</PrivateAssets>
</PackageReference>
</ItemGroup>

</Project>
"@ > $BuildProjectFile

    foreach ($ModuleItem in $Packages.keys) {

        $dotnetArgs = 'add',$BuildProjectFile,'package',$ModuleItem

        if ($Packages[$ModuleItem] -ne $true) {
            $dotNetArgs += '--no-restore'
            $dotnetArgs += '--version'
            $dotnetArgs += $Packages[$ModuleItem]
        }
        write-verbose "Executing: dotnet $dotnetArgs"
        & dotnet $dotnetArgs | Write-Verbose
    }

    & dotnet publish -o $BuildPath $BuildProjectFile | Write-Verbose

    function ConvertFromModuleDeps ($Path) {
        $runtimeDeps = Get-Content -raw $Path | ConvertFrom-Json
        $depResult = [ordered]@{}
        $runtimeDeps.targets.$TargetFullName.psobject.Properties.name |
            Where-Object {$PSItem -notlike "$BuildProjectName*"} |
            Sort-Object |
            Foreach-Object {
                $depInfo = $PSItem -split '/'
                $depResult[$depInfo[0]] = $depInfo[1]
            }
        return $depResult
    }
    #Use return to end script here and don't actually copy the files
    $ModuleDeps = ConvertFromModuleDeps -Path $BuildPath/obj/project.assets.json

    if (-not $Destination) {
        #Output the Module Dependencies and end here
        Remove-Item $BuildPath -Force -Recurse
        return $ModuleDeps
    }

    if ($PSCmdlet.ShouldProcess($Destination,"Copy Resultant DLL Assemblies")) {
        New-Item -ItemType Directory $Destination -Force > $null
        $CopyItemParams = @{
            Path = "$BuildPath/*.dll"
            Exclude = "$BuildProjectName.dll"
            Destination = $Destination
            Force = $true
        }

        if ($PassThru) {$CopyItemParams.PassThru = $true}
        Copy-Item @CopyItemParams
        Remove-Item $BuildPath -Force -Recurse
    }
}