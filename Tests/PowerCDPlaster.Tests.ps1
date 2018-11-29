#requires -version 5 -module Pester,Plaster
#Integration Test: Deploy the PowerCD plaster template and verify the deployment
param (
    #Specify an alternate location for the Powershell Module. This is useful when testing a build in another directory
    [string]$ModulePath = (Get-Location),
    #The parameters required for a "silent" deployment of the template using invoke-pester. This will depend on your template
    [hashtable]$PlasterParams = [ordered]@{
        ModuleName='PowerCDPlasterTest'
        ModuleDesc='Generated automatically by Pester for integration testing. Delete this if you find it'
        Version='0.0.1'
        FullName='PowerCDPlasterTestUser'
        FirstFunctionName='Test-PowerCDwithPlaster'
        License='GNU'
        Editor='None'
        Appveyor='N'
        AzureDevOpsPipelines='N'
    }
)

#if we are in the "Tests" directory and there is a PSD file below this one, change to the module directory so relative paths work correctly.
$currentDir = Get-Location
if (
    (Test-Path $currentDir -PathType Container) -and
    $currentDir -match 'Tests$' -and
    (Get-Item (join-path ".." "*.psd1"))
) {
    $ModulePath = (split-path $modulepath)
}

#If an alternate module root was specified, set that to our running directory.
if ($ModulePath -ne (get-location).path) {Push-Location $ModulePath}
Describe 'PowerCD Plaster Template' {
    $PowershellEXEPath = if ($isCoreCLR) {(Get-command pwsh).source} else {(get-command powershell).source}
    context 'Plaster Manifest' {
        $SCRIPT:PlasterManifestPath = get-item (join-path $ModulePath 'PlasterTemplates\Default\plasterManifest.xml')
        #TODO: Plaster Manifest detection logic
        It -Pending 'Has a Plaster manifest specified in the module manifest'
        It -Pending 'Has a Plaster manifest file where specified'
        It 'Has a valid Plaster Manifest' {
            $SCRIPT:PlasterManifest = Test-PlasterManifest $PlasterManifestPath
            $PlasterManifest | Should BeOfType 'System.Xml.XmlDocument'
        }

        #Fetch the default parameters, and expand out the "choice parameters"
        $SCRIPT:PlasterManifestDefaults = [ordered]@{}
        $manifestParams = $plastermanifest.plasterManifest.parameters.parameter
        $manifestParams |
            select name,default |
            foreach {
                $PlasterManifestDefaults.($PSItem.Name) = $PSItem.default
            }

        #This code is ugly because of XML, it just gets the choice value corresponding to the default choice index
        $manifestParams | where type -eq 'Choice' | foreach {
            $PlasterManifestDefaults[$PSItem.Name] = $PSItem.choice[$PSItem.default].value
        }

        It 'Has defaults specified for all parameters' {
            $PlasterManifestDefaults.keys | where {$PlasterManifestDefaults.$PSItem -eq $null} | Should BeNullOrEmpty
        }
    }

    context 'Default Deployment' {
        #Get the default parameters from the script
        $PlasterManifest = get-item (join-path $ModulePath 'PlasterTemplates\Default\plasterManifest.xml')
        $PlasterManifestDirectory = Split-Path -Path $PlasterManifest -Parent
        $PlasterDeployPath = join-path 'TestDrive:' ([io.path]::GetRandomFileName())
        $PlasterDeployPath = New-Item -Type Directory $PlasterDeployPath
        $PlasterOutputFile = join-path 'TestDrive:' ([io.path]::GetRandomFileName())

        It "Invoke-Plaster to TestDrive is successful" {
            invoke-plaster -TemplatePath $PlasterManifestDirectory -DestinationPath $PlasterDeployPath @PlasterManifestDefaults 6>$null
            test-path (join-path $PlasterDeployPath "MyNewModule\MyNewModule.psd1") | Should Be $true
        }

        It "Invoke-Build on the template succeeds" {
            Push-Location $PlasterDeployPath
            try {
                git init -q
                git config --local user.email "plasterTestBuild@notrealemail.local"
                git config --local user.name "PlasterTestBuild-DONOTUSE"
                git add .
                git commit -m 'Plaster Initial Test Commit'
                #Run Invoke-Build in a separate powershell process to avoid any scope issues
                $InvokeBuildOutput = & $PowershellEXEPath -noprofile -noninteractive -command {.\build.ps1 -Task Build,Test -SkipBootStrap} *>&1

                $LASTEXITCODE | Should Be 0
            } catch {
                throw "Invoke-Build on $PlasterDeployPath failed: $PSItem at $($PSItem.ScriptStackTrace)"
            }
            Pop-Location
        }
    }

    context 'Custom Deployment' {
        #Get the default parameters from the script
        $PlasterManifest = get-item (join-path $ModulePath 'PlasterTemplates\Default\plasterManifest.xml')
        $PlasterManifestDirectory = Split-Path -Path $PlasterManifest -Parent
        $PlasterDeployPath = join-path 'TestDrive:' ([io.path]::GetRandomFileName())
        $PlasterDeployPath = New-Item -Type Directory $PlasterDeployPath
        $PlasterOutputFile = join-path 'TestDrive:' ([io.path]::GetRandomFileName())

        It "Invoke-Plaster to TestDrive is successful" {
            invoke-plaster -TemplatePath $PlasterManifestDirectory -DestinationPath $PlasterDeployPath @PlasterParams 6>$null
            test-path (join-path $PlasterDeployPath 'PowerCDPlasterTest\PowerCDPlasterTest.psd1') | Should Be $true
        }

        It "Invoke-Build on the template succeeds" {
            Push-Location $PlasterDeployPath
            try {
                git init -q
                git config --local user.email "plasterTestBuild@notrealemail.local"
                git config --local user.name "PlasterTestBuild-DONOTUSE"
                git add .
                git commit -m 'Plaster Initial Test Commit'
                #Run Invoke-Build in a separate powershell process to avoid any scope issues
                $InvokeBuildOutput = & $PowershellEXEPath -noprofile -noninteractive -command {.\build.ps1 -Task Build,Test -SkipBootStrap} *>&1
                $LASTEXITCODE | Should Be 0
            } catch {
                throw "Invoke-Build on $PlasterDeployPath failed: $PSItem at $($PSItem.ScriptStackTrace)"
            }
            Pop-Location
        }
    }
}

#Return to the original invoking directory
Pop-Location