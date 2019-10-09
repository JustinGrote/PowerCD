#requires -module BuildHelpers

function Invoke-PowerCDClean {
    [CmdletBinding()]
    param (
        $buildProjectPath = $pcdSetting.Environment.ProjectPath,
        $buildOutputPath  = $pcdSetting.Environment.BuildOutput,
        $buildProjectName = $pcdSetting.Environment.ProjectName
    )

    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        Remove-BuildItem $buildOutputPath
    }

    New-Item -Type Directory $BuildOutputPath > $null

    #Unmount any modules named the same as our module
    Remove-Module $buildProjectName -erroraction silentlycontinue
}

