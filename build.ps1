Install-Module BuildHelpers -scope currentuser -Force
Import-Module BuildHelpers
Get-BuildEnvironment | fl | out-string

$psversiontable.psversion