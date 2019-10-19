
function Select-HashTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)][Hashtable]$Hashtable,
        [String[]]$Include,
        [String[]]$Exclude
    )

    if (-not $Include) {$Include = $HashTable.Keys}

    $filteredHashTable = @{}
    $HashTable.keys.where{
        $PSItem -in $Include
    }.where{
        $PSItem -notin $Exclude
    }.foreach{
        $filteredHashTable[$PSItem] = $HashTable[$PSItem]
    }
    return $FilteredHashTable
}