Enter-Build {
    Initialize-PowerCD
}

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


task PowerCD.UpdateVersion {
    Set-PowerCDVersion
}

task PowerCD.UpdatePublicFunctions {
    Update-PowerCDPublicFunctions
}

task PowerCD.Test.Pester {
    Test-PowerCDPester -OutputPath $PCDSetting.buildenvironment.buildoutput
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
task PowerCD.Build @(
    'PowerCD.Version'
    'PowerCD.BuildPSModule'
    'PowerCD.UpdateVersion'
    'PowerCD.UpdatePublicFunctions'
)
task PowerCD.Package @(
    'PowerCD.Package.Zip'
    'PowerCD.Package.Nuget'
)
task PowerCD.Test @(
    'PowerCD.Test.Pester'
)
task PowerCD.Default @(
    'PowerCD.Clean'
    'PowerCD.Build'
    'PowerCD.Test'
)
#endregion MetaTasks

#region Defaults
task Clean PowerCD.Clean
task Build PowerCD.Build
task Test PowerCD.Test
task Package PowerCD.Package
task . PowerCD.Default
#endregion Defaults