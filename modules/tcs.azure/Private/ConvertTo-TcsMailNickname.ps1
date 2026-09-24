<#
.SYNOPSIS
    Builds a valid Microsoft Entra ID mail nickname.

.DESCRIPTION
    Private helper. Returns Prefix + Text + Suffix as a mail nickname that Microsoft Entra ID accepts:
      - accents are removed from letters (the text is decomposed, Unicode FormD, and the combining
        marks are dropped, so an A with an umlaut becomes a plain A);
      - characters Entra ID does not allow in a mail nickname are removed: anything outside printable
        ASCII, and @ ( ) \ [ ] " ; : < > ,
      - when nothing is left of the text, a stable 8-character hash of HashSource is used instead;
      - when the result is longer than 64 characters, the text is shortened and a hash of HashSource
        is added before the suffix, so different long names still get different nicknames.
    Prefix and Suffix must already be valid nickname characters.

.PARAMETER Text
    The variable part of the nickname, for example an application name.

.PARAMETER Prefix
    Fixed text before the variable part, for example 'Intune-AG-'.

.PARAMETER Suffix
    Fixed text after the variable part, for example '-Available'. It is always kept.

.PARAMETER HashSource
    The value the hash is calculated from, normally the full group display name.
#>
function ConvertTo-TcsMailNickname {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Text,

        [string]
        $Prefix = '',

        [string]
        $Suffix = '',

        [Parameter(Mandatory = $true)]
        [string]
        $HashSource
    )

    $maxLength = 64
    $decomposed = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object -TypeName System.Text.StringBuilder
    foreach ($character in $decomposed.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            $null = $builder.Append($character)
        }
    }
    $core = $builder.ToString() -replace '[^\x21-\x7E]|[@()\\\[\]";:<>,]', ''

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($HashSource))
    }
    finally {
        $sha.Dispose()
    }
    $hash = -join ($hashBytes[0..3] | ForEach-Object { $_.ToString('x2') })

    if (-not $core) {
        $core = $hash
    }

    $nickname = $Prefix + $core + $Suffix
    if ($nickname.Length -gt $maxLength) {
        $room = $maxLength - $Prefix.Length - $Suffix.Length - $hash.Length - 1
        $nickname = $Prefix + $core.Substring(0, [Math]::Max($room, 0)).TrimEnd('-', '.') + '-' + $hash + $Suffix
    }
    $nickname
}
