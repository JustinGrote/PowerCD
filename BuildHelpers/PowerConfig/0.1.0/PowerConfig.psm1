using namespace Microsoft.Extensions.Configuration
#Load Assemblies
function Import-Assembly {
<#
.SYNOPSIS
Adds Binding Redirects for Certain Assemblies to make them more flexibly compatible with Windows Powershell
#>
    [CmdletBinding()]
    param(
        #Path to the dependencies that you wish to add a binding redirect for
        [Parameter(Mandatory)][IO.FileInfo[]]$Path
    )
    if ($PSEdition -ne 'Desktop') {
        write-warning "Import-Assembly is only required on Windows Powershell and not Powershell Core. Skipping..."
        return
    }

    $pathAssemblies = $path.foreach{
        [reflection.assemblyname]::GetAssemblyName($PSItem)
    }
    $loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies()
    #Bootstrap the required types in case this loads really early
    $null = Add-Type -AssemblyName mscorlib

    $onAssemblyResolveEventHandler = [ResolveEventHandler] {
        param($sender, $assemblyToResolve)

        try {
            $ErrorActionPreference = 'stop'
            [String]$assemblyToResolveStrongName = $AssemblyToResolve.Name
            [String]$assemblyToResolveName = $assemblyToResolveStrongName.split(',')[0]
            write-verbose "Import-Assembly: Resolving $AssemblyToResolveStrongName"
            
            #Try loading from our custom assembly list
            $bindingRedirectMatch = $pathAssemblies.where{
                $PSItem.Name -eq $assemblyToResolveName
            }
            if ($bindingRedirectMatch) {
                write-verbose "Import-Assembly: Creating a 'binding redirect' to $BindingRedirectMatch"
                return [reflection.assembly]::LoadFrom($bindingRedirectMatch.CodeBase)
            }

            #Bugfix for System.Management.Automation.resources which comes up from time to time
            #TODO: Find the underlying reason why it asks for en instead of en-us
            if ($AssemblyToResolveStrongName -like 'System.Management.Automation.Resources*') {
                $AssemblyToResolveStrongName = $AssemblyToResolveStrongName -replace 'Culture\=en\-us','Culture=en'
                write-verbose "BUGFIX: $AssemblyToResolveStrongName"
            }

            Add-Type -AssemblyName $AssemblyToResolveStrongName -ErrorAction Stop
            return [System.AppDomain]::currentdomain.GetAssemblies() | where fullname -eq $AssemblyToResolveStrongName
            #Add Type doedsn'tAssume successful and return the object. This will be null if it doesn't exist and will fail resolution anyways

        } catch {
            write-host -fore red "Error finding $AssemblyToResolveName`: $($PSItem.exception.message)"
            return $null
        }

        #Return a null as a last resort
        return $null
    }
    [AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolveEventHandler)

    Add-Type -Path $Path

    [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($onAssemblyResolveEventHandler)
}

$ImportAssemblies = Get-Item "$PSScriptRoot/lib/*.dll"
if ($PSEdition -eq 'Desktop') {
    Import-Assembly -Path $ImportAssemblies
} else {
    Add-Type -Path $ImportAssemblies
}

#Add Back Extension Methods for ease of use
#TODO: Make this a method


try {
    Update-TypeData -Erroraction Stop -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
        param([String]$Path)
        [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
    }
} catch {
    if ([String]$PSItem -match 'The member .+ is already present') {
        write-verbose "Extension Method already present"
        $return
    }
    #Write-Error $PSItem.exception
}

try {
    Update-TypeData -Erroraction Stop -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddJsonFile -MemberType ScriptMethod -Value {
        param([String]$Path)
        [Microsoft.Extensions.Configuration.JsonConfigurationExtensions]::AddJsonFile($this, $Path)
    }
} catch {
    if ([String]$PSItem -match 'The member .+ is already present') {
        write-verbose "Extension Method already present"
        $return
    }
    #Write-Error $PSItem.exception
}


# if ('AddYamlFile' -notin (get-typedata "Microsoft.Extensions.Configuration.ConfigurationBuilder").members.keys) {
#     Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
#         param([String]$Path)
#         [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
#     }
# }
#Taken with love from https://github.com/austoonz/Convert/blob/master/src/Convert/Public/ConvertFrom-StringToMemoryStream.ps1

<#
    .SYNOPSIS
        Converts a string to a MemoryStream object.
    .DESCRIPTION
        Converts a string to a MemoryStream object.
    .PARAMETER String
        A string object for conversion.
    .PARAMETER Encoding
        The encoding to use for conversion.
        Defaults to UTF8.
        Valid options are ASCII, BigEndianUnicode, Default, Unicode, UTF32, UTF7, and UTF8.
    .PARAMETER Compress
        If supplied, the output will be compressed using Gzip.
    .EXAMPLE
        $stream = ConvertFrom-StringToMemoryStream -String 'A string'
        $stream.GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     MemoryStream                             System.IO.Stream
    .EXAMPLE
        $stream = 'A string' | ConvertFrom-StringToMemoryStream
        $stream.GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     MemoryStream                             System.IO.Stream
    .EXAMPLE
        $streams = ConvertFrom-StringToMemoryStream -String 'A string','Another string'
        $streams.GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     Object[]                                 System.Array
        $streams[0].GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     MemoryStream                             System.IO.Stream
    .EXAMPLE
        $streams = 'A string','Another string' | ConvertFrom-StringToMemoryStream
        $streams.GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     Object[]                                 System.Array
        $streams[0].GetType()
        IsPublic IsSerial Name                                     BaseType
        -------- -------- ----                                     --------
        True     True     MemoryStream                             System.IO.Stream
    .EXAMPLE
        $stream = ConvertFrom-StringToMemoryStream -String 'This string has two string values'
        $stream.Length
        33
        $stream = ConvertFrom-StringToMemoryStream -String 'This string has two string values' -Compress
        $stream.Length
        10
    .OUTPUTS
        [System.IO.MemoryStream[]]
    .LINK
        http://convert.readthedocs.io/en/latest/functions/ConvertFrom-StringToMemoryStream/
#>
function ConvertFrom-StringToMemoryStream
{
    [CmdletBinding(HelpUri = 'http://convert.readthedocs.io/en/latest/functions/ConvertFrom-StringToMemoryStream/')]
    param
    (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $String,

        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [String]
        $Encoding = 'UTF8',

        [Switch]
        $Compress
    )

    begin
    {
        $userErrorActionPreference = $ErrorActionPreference
    }

    process
    {
        foreach ($s in $String)
        {
            try
            {
                [System.IO.MemoryStream]$stream = [System.IO.MemoryStream]::new()
                if ($Compress)
                {
                    $byteArray = [System.Text.Encoding]::$Encoding.GetBytes($s)
                    $gzipStream = [System.IO.Compression.GzipStream]::new($stream, ([IO.Compression.CompressionMode]::Compress))
                    $gzipStream.Write( $byteArray, 0, $byteArray.Length )
                }
                else
                {
                    $writer = [System.IO.StreamWriter]::new($stream)
                    $writer.Write($s)
                    $writer.Flush()
                }
                $stream
            }
            catch
            {
                Write-Error -ErrorRecord $_ -ErrorAction $userErrorActionPreference
            }
        }
    }
}
function ConvertTo-Dictionary {
    [CmdletBinding()]
    param (
        [System.Collections.HashTable]$Hashtable
    )
    #Make a string dictionary that the memorycollection requires
    $dictionary = [System.Collections.Generic.Dictionary[String,String]]::new()

    #Take the hashtable values and import them into the dictionary
    $hashtable.keys.foreach{
        $null = $Dictionary.Add($PSItem,$HashTable[$PSItem])
    }

    return $dictionary
}
<#
.SYNOPSIS
Takes an enumerable keyvaluepair from Microsoft.Extensions.Configuration and converts it to a nested hashtable
#>

#Create a "type accelerator" of sorts
class SortedDictionary : System.Collections.Generic.SortedDictionary[string,object] {}

function ConvertTo-NestedHashTable {
    [CmdletBinding()]
    param (
        [Collections.Generic.KeyValuePair[String,String][]]$InputObject
    )

    #First group the entries by hierarchy
    $depthGroups = $InputObject | Group-Object {
        $PSItem.key.split(':').count
    }
    $result = [ordered]@{}

    foreach ($DepthItem in $DepthGroups) {
        $depth = $DepthItem.Name
        foreach ($ConfigItem in ($DepthItem.Group)) {
            $ConfigItemLevels = $ConfigItem.key.split(':')

            #Iterate through the levels and create them if not already present
            $lastLevel = $result
            For ($i=0;$i -lt ($ConfigItemLevels.count -1);$i++) {
                if ($lastLevel[$ConfigItemLevels[$i]] -isnot [hashtable]) {
                    $lastLevel[$ConfigItemLevels[$i]] = [ordered]@{}
                }
                #Step up to the new level for the next activity
                $lastLevel = $lastLevel[$ConfigItemLevels[$i]]
            }

            #Assign the value now that the levels have been created
            $valueKey = $ConfigItemLevels[($ConfigItemLevels.count -1)]
            $lastLevel.$valueKey = $ConfigItem.Value
        }
    }

    return $result
}
function Add-PowerConfigCommandLineSource {
    [CmdletBinding(PositionalBinding=$false)]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        # A hashtable that remaps arguments to their intented destination, for instance @{'-f'='force'} remaps the shorthand -f to the force key
        [HashTable]$ArgumentMap,
        #The arguments that were passed to your script. You can pass the arguments directly to this script, or supply them as a variable similar to $args (an array of strings, one statement per string)
        [Parameter(Mandatory,ValueFromRemainingArguments)]$ArgumentList
    )

    #Couldn't cast a hashtable directly because it was seeing it as new properties, so here is a workaround
    $ArgumentMapDictionary = [Collections.Generic.Dictionary[String,String]]::new()
    $ArgumentMap.keys.foreach{
        $ArgumentMapDictionary[$PSItem] = $ArgumentMap[$PSItem]
    }

    [CommandLineConfigurationExtensions]::AddCommandLine($InputObject, $ArgumentList, $ArgumentMapDictionary)
}
function Add-PowerConfigEnvironmentVariableSource {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The prefix for your environment variables. Default is no prefix
        [String]$Prefix = ''
    )

    [EnvironmentVariablesExtensions]::AddEnvironmentVariables($InputObject, $Prefix)
}
function Add-PowerConfigJsonSource {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The prefix for your environment variables. Default is no prefix
        [Parameter(Mandatory)]$Path,
        #Specify this parameter if the configuration file is mandatory. PowerConfig will show an error if this file is not present.
        [Switch]$Mandatory,
        #By default, if the file changes the configuration will automatically be updated. If you want to disable this behavior, specify this parameter.
        [Switch]$NoRefresh
    )

    [JsonConfigurationExtensions]::AddJsonFile($InputObject, $Path, !$Mandatory, !$NoRefresh)
}
function Add-PowerConfigObject {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The hashtable to add to your configuration values. Use colons (:) to separate sections of configuration
        [Parameter(Mandatory)][Object]$Object,
        #How deep to go on nested properties. You should normally not touch this and instead filter your inputs first
        $Depth = 5,
        #Optional path to save the converted Json. This is normally a temporary file and you shouldn't need to change this.
        $JsonTempFile = [io.path]::GetTempFileName()
    )

    $ObjectJson = $Object | ConvertTo-Json -Compress -ErrorAction Stop | Out-File -FilePath $JsonTempFile
    [JsonConfigurationExtensions]::AddJsonFile($InputObject,$JsonTempFile)

    #TODO: Use the stream method when we can bump to Configuration Extensions 3.0
    #$JsonStream = ConvertFrom-StringToMemoryStream $ObjectJson
    #[JsonConfigurationExtensions]::AddJsonStream($InputObject,$JsonStream)
}
function Add-PowerConfigYamlSource {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The prefix for your environment variables. Default is no prefix
        [Parameter(Mandatory)]$Path,
        #Specify this parameter if the configuration file is mandatory. PowerConfig will show an error if this file is not present.
        [Switch]$Mandatory,
        #By default, if the file changes the configuration will automatically be updated. If you want to disable this behavior, specify this parameter.
        [Switch]$NoRefresh
    )

    [YamlConfigurationExtensions]::AddYamlFile($InputObject, $Path, !$Mandatory, !$NoRefresh)
}
function Get-PowerConfig {
    param (
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject
    )

    $RenderedPowerConfig = $InputObject.build()
    ConvertTo-NestedHashTable ([ConfigurationExtensions]::AsEnumerable($RenderedPowerConfig))
}

<#
.SYNOPSIS
    Create a new Powerconfig Object
#>
function New-PowerConfig {
    [CmdletBinding()]
    param()

    #TODO: Intelligent Defaults
    [ConfigurationBuilder]::new()
}

