#requires -Version 2.0
<#
    .NOTES
    ===========================================================================
     Filename              : Merge-Hashtables.ps1
     Created on            : 2014-09-04
     Created by            : Frank Peter Schultze
    ===========================================================================

    .SYNOPSIS
        Create a single hashtable from two hashtables where the second given
        hashtable will override.

    .DESCRIPTION
        Create a single hashtable from two hashtables. In case of duplicate keys
        the function the second hashtable's key values "win". Merge-Hashtables
        supports nested hashtables.

    .EXAMPLE
        $configData = Merge-Hashtables -First $defaultData -Second $overrideData

    .INPUTS
        None

    .OUTPUTS
        System.Collections.Hashtable
#>
function Merge-Hashtables
{
    [CmdletBinding()]
    Param
    (
        #Identifies the first hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $First
    ,
        #Identifies the second hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $Second
    )

    function Set-Keys ($First, $Second)
    {
        @($First.Keys) | Where-Object {
            $Second.ContainsKey($_)
        } | ForEach-Object {
            if (($First.$_ -is [Hashtable]) -and ($Second.$_ -is [Hashtable]))
            {
                Set-Keys -First $First.$_ -Second $Second.$_
            }
            else
            {
                $First.Remove($_)
                $First.Add($_, $Second.$_)
            }
        }
    }

    function Add-Keys ($First, $Second)
    {
        @($Second.Keys) | ForEach-Object {
            if ($First.ContainsKey($_))
            {
                if (($Second.$_ -is [Hashtable]) -and ($First.$_ -is [Hashtable]))
                {
                    Add-Keys -First $First.$_ -Second $Second.$_
                }
            }
            else
            {
                $First.Add($_, $Second.$_)
            }
        }
    }

    # Do not touch the original hashtables
    $firstClone  = $First.Clone()
    $secondClone = $Second.Clone()

    # Bring modified keys from secondClone to firstClone
    Set-Keys -First $firstClone -Second $secondClone

    # Bring additional keys from secondClone to firstClone
    Add-Keys -First $firstClone -Second $secondClone

    # return firstClone
    $firstClone
}
