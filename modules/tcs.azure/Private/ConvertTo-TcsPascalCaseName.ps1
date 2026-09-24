<#
.SYNOPSIS
    Joins the words of a name in PascalCase.

.DESCRIPTION
    Private helper shared by the tcs.azure naming commands. Words are split on any run of whitespace,
    the first character of each word is upper-cased with the invariant culture and the rest of the
    word is kept as written, so acronyms ('IT', 'HR') and mixed-case words ('PowerShell') are kept and
    hyphenated words ('7-zip') are not split. Returns an empty string when there are no words.

.PARAMETER Text
    The text to convert.
#>
function ConvertTo-TcsPascalCaseName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Text
    )

    $words = @($Text -split '\s+' | Where-Object { $_ })
    $converted = foreach ($word in $words) {
        # ToUpperInvariant: with the current culture, 'i' becomes a dotted capital I under tr-TR
        $word.Substring(0, 1).ToUpperInvariant() + $word.Substring(1)
    }
    -join @($converted)
}
