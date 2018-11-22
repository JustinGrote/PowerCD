@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    Pester                          = @{
        Version     = 'latest'
        Parameters  = @{
            SkipPublisherCheck = $true
        }
    }
    BuildHelpers                    = 'latest'
    'powershell-yaml'               = 'latest'
    'Microsoft.Powershell.Archive'  = 'latest'
    PSScriptAnalyzer                = 'latest'
    Plaster                         = 'latest'
}