Describe "Import" {
    It "Imports the Module Successfully" {
        "Pester TestInit Working Directory: $(pwd)" | write-host -fore Magenta
        Import-Module ./BuildOutput/PowerCD -force -passthru | Should -Not -BeNullOrEmpty
    }
}