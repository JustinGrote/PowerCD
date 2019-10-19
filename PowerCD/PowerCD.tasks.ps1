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
    Test-PowerCDPester -CodeCoverage $null
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