function Copy-PowerCDBuildFiles {
    [CmdletBinding()]
    param (
        $PSModuleManifestDirectory = $pcdSetting.Environment.ModulePath,
        $BuildReleasePath = $pcdSetting.Environment.BuildOutput
    )

    #Detect the .psm1 file and copy all files to the root directory, excluding build files unless this is PowerCD
    if ($PSModuleManifestDirectory -eq $buildRoot) {
        <# TODO: Root-folder level module with buildFilesToExclude
        copy-item -Recurse -Path $buildRoot\* -Exclude $BuildFilesToExclude -Destination $BuildReleasePath @PassThruParams
        #>
        throw "Placing module files in the root project folder is current not supported by this script. Please put them in a subfolder with the name of your module"
    } else {
        Copy-Item -Container -Recurse -Path $PSModuleManifestDirectory\* -Destination $BuildReleasePath
    }
}