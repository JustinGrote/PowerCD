#requires -module InvokeBuild
task Clean.PowerCD Init.PowerCD,{
    $buildProjectPath = $pcdSetting.BuildEnvironment.ProjectPath
    $buildOutputPath  = $pcdSetting.BuildEnvironment.BuildOutput
    $buildProjectName = $pcdSetting.BuildEnvironment.ProjectName

    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        Remove-BuildItem $buildOutputPath
    }

    New-Item -Type Directory $BuildOutputPath > $null

    #Unmount any modules named the same as our module
    Remove-Module $buildProjectName -erroraction silentlycontinue
}