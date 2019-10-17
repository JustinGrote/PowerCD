using namespace System.IO
#requires -module BuildHelpers
<#
.SYNOPSIS
Builds a settings object (nested hashtable).
.DESCRIPTION
This builds a layered settings object that starts with intelligent defaults, and then imports the user preferences from a build.psd1 file.
Once built the object is saved as a readonly Hashtable, which allows changing the values but not the structure, for safety, so the user can also edit the values directly
.NOTES
#TODO: Support YAML and JSON input, maybe switch to Microsoft.Extensions.Configuration
#>

function Get-PowerCDSetting {
    [CmdletBinding()]
    param(
        #Path to the initial PowerCDSettings File.
        $Path
    )

    function New-SortedDictionary ([String]$ValueType='Object') {
        new-object "Collections.Generic.SortedDictionary[String,$ValueType]" -ArgumentList ([StringComparer]::OrdinalIgnoreCase)
    }

    #Initialize the Settings Builder as a case-insensitive autosorting hashtable
    #TODO: Consider doing this as a class to enforce type safety
    $PowerCDSettings = New-SortedDictionary

    #Import the Build Environment
    $PowerCDSettings.Environment = New-SortedDictionary 'String'
    (BuildHelpers\Get-BuildEnvironment).psobject.properties | Sort-Object name | Foreach-Object {
        $PowerCDSettings.Environment[$PSItem.Name] = [String]$PSItem.Value
    }



    #TODO: Pull in environment variables

    return $PowerCDSettings
}