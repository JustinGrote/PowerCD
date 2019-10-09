Install-Module BuildHelpers -scope currentuser -Force
Import-Module BuildHelpers
Get-BuildEnvironment | ft | out-string
