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
<#
#TODO: Inject this code into the module psm1 file
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
#>
