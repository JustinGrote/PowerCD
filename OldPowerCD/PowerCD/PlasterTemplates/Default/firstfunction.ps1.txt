function <%=$PLASTER_PARAM_FirstFunctionName%> {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>

    [CmdletBinding()]
    param (
        #Describe what the parameter does using comments like this and they will show up in Get-Help.
        [String]$Message = "Hello World!"
    )

    begin {
    }

    process {
        write-host -Foreground Green $Message
    }

    end {
    }
}