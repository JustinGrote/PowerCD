function Resolve-PowerCDModuleManifest {

    Get-PSModuleManifest -WarningVariable GetPSModuleManifestWarning -WarningAction SilentlyContinue
}