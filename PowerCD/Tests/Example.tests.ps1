Describe "Import" {
    It "Imports the Module Successfully" {
        Import-Module ./BuildOutput/PowerCD -force -passthru | Should -Not -BeNullOrEmpty
    }
}