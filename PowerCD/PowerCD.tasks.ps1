task Clean.PowerCD {
    Invoke-PowerCDClean
}

task Version.PowerCD {
    . Get-PowerCDVersion > $null
}

task BuildPSModule.PowerCD {
    Build-PowerCDModule
}

#region PowerCDSpecific

#endRegion PowerCDSpecific


task SetPSModuleVersion.PowerCD {
    Set-PowerCDVersion
}

task UpdatePSModulePublicFunctions.PowerCD {
    Update-PowerCDPublicFunctions
}

task TestPester.PowerCD {
    Test-PowerCDPester -CodeCoverage $null -Show All -ModuleManifestPath $PCDSetting.OutputModuleManifest
}

task PackageNuget.PowerCD {
    $TaskParams = @{
        Path = [IO.Path]::Combine(
            $PCDSetting.BuildEnvironment.BuildOutput,
            $PCDSetting.BuildEnvironment.ProjectName,
            $PCDSetting.Version
        )
        Destination = $PCDSetting.BuildEnvironment.BuildOutput
    }
    New-PowerCDNugetPackage @TaskParams
}

task PackageZip.PowerCD {
    [String]$ZipFileName = $PCDSetting.BuildEnvironment.ProjectName + '-' + $PCDSetting.VersionLabel + '.zip'

    $CompressArchiveParams = @{
        Path = $PCDSetting.BuildEnvironment.ModulePath
        Destination = join-path $PCDSetting.BuildEnvironment.BuildOutput $ZipFileName
    }

    Compress-PowerCDModule @CompressArchiveParams
}

#TODO: Make PowerCD-Specific task for this
task CopyBuildTasksFile {
    if (Test-Path "$BuildRoot\PowerCD\PowerCD.tasks.ps1") {
        Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0]
    }

}

task Build.PowerCD Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,CopyBuildTasksFile
task Package.PowerCD PackageZip.PowerCD,PackageNuget.PowerCD
task Test.PowerCD TestPester.PowerCD

task Default.PowerCD Clean.PowerCD,Build.PowerCD,Test.PowerCD,Package.PowerCD