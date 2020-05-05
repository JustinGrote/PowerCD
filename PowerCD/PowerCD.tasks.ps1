task PowerCD.Clean {
    Invoke-PowerCDClean
}
task PowerCD.CleanPrerequisites {
    Invoke-PowerCDClean -Prerequisites
}

task PowerCD.Version {
    . Get-PowerCDVersion > $null
}

task PowerCD.BuildPSModule {
    Build-PowerCDModule
}

#region PowerCDSpecific

#TODO: Make PowerCD-Specific task for this
task PowerCD.CopyBuildTasks {
    if (Test-Path "$BuildRoot\PowerCD\PowerCD.tasks.ps1") {
        Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0]
    }
}

#endRegion PowerCDSpecific


task PowerCD.UpdateVersion {
    Set-PowerCDVersion
}

task PowerCD.UpdatePublicFunctions {
    Update-PowerCDPublicFunctions
}

task PowerCD.Test.Pester {
    Test-PowerCDPester -CodeCoverage $null -Show All -ModuleManifestPath $PCDSetting.OutputModuleManifest
}

task PowerCD.Package.Nuget {
    $TaskParams = @{
        Path = [IO.Path]::Combine(
            $PCDSetting.BuildEnvironment.BuildOutput,
            $PCDSetting.BuildEnvironment.ProjectName,
            $PCDSetting.Version
        )
        Destination = $PCDSetting.BuildEnvironment.BuildOutput
    }
    if ($MetaBuildPath) {
        #Import the Compress-PowerCDModule Command
        . ([IO.Path]::Combine($MetaBuildPath.Directory,'Public','New-PowerCDNugetPackage.ps1'))
    }

    New-PowerCDNugetPackage @TaskParams

    #Meta Build Cleanup
    if ($MetaBuildPath) {Remove-Item Function:/New-PowerCDNugetPackage}
}

task PowerCD.Package.Zip {
    [String]$ZipFileName = $PCDSetting.BuildEnvironment.ProjectName + '-' + $PCDSetting.VersionLabel + '.zip'

    $CompressArchiveParams = @{
        Path = $PCDSetting.BuildModuleOutput
        Destination = join-path $PCDSetting.BuildEnvironment.BuildOutput $ZipFileName
    }
    if ($MetaBuildPath) {
        #Import the Compress-PowerCDModule Command
        . ([IO.Path]::Combine($MetaBuildPath.Directory,'Public','Compress-PowerCDModule.ps1'))
    }

    Compress-PowerCDModule @CompressArchiveParams

    #Meta Build Cleanup
    if ($MetaBuildPath) {Remove-Item Function:/Compress-PowerCDModule}
}

#region MetaTasks
task PowerCD.Build PowerCD.Version,PowerCD.BuildPSModule,PowerCD.UpdateVersion,PowerCD.UpdatePublicFunctions,PowerCD.CopyBuildTasks
task PowerCD.Package PowerCD.Package.Zip,PowerCD.Package.Nuget
task PowerCD.Test PowerCD.Test.Pester
task PowerCD.Default PowerCD.Clean,PowerCD.Build,PowerCD.Test,PowerCD.Package
#endregion MetaTasks