<#
.SYNOPSIS
    Builds a departmental group name.

.DESCRIPTION
    Private helper behind Get-DepartmentalGroupName and New-TcsEntraDepartmentalGroup. See the help of
    Get-DepartmentalGroupName for the naming rules. Returns nothing when the division has no usable
    words after clean-up.

.PARAMETER Prefix
    The first part of the name.

.PARAMETER Division
    The division.

.PARAMETER Department
    The optional department.

.PARAMETER Suffix
    The optional last part of the name.
#>
function ConvertTo-DepartmentalGroupName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Prefix,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Division,

        [string]
        $Department,

        [string]
        $Suffix
    )

    $stopWords = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($stopWord in @('and', 'of', 'the', '&')) {
        $null = $stopWords.Add($stopWord)
    }

    # Splits text into segments (arrays of words). A hyphen on its own ('HR - Payroll') or at the start
    # or end of a word separates segments; a hyphen inside a word ('7-zip') is kept.
    $getSegments = {
        param([string]$Text)
        $clean = $Text -replace '&', ' and '
        # Apostrophes (straight, typographic U+2019 and backtick) are removed so "Children's" stays one word
        $clean = $clean -replace ('[''`{0}]' -f [char]0x2019), ''
        $clean = $clean -replace '[^\p{L}\p{M}\p{Nd}\s-]', ' '
        $segments = New-Object -TypeName 'System.Collections.Generic.List[object]'
        $current = New-Object -TypeName 'System.Collections.Generic.List[string]'
        foreach ($token in @($clean -split '\s+' | Where-Object { $_ })) {
            $word = ($token -replace '-{2,}', '-').Trim('-')
            if ($token.StartsWith('-') -and $current.Count -gt 0) {
                $segments.Add($current.ToArray())
                $current.Clear()
            }
            if ($word) {
                $current.Add($word)
            }
            if ($token.EndsWith('-') -and $current.Count -gt 0) {
                $segments.Add($current.ToArray())
                $current.Clear()
            }
        }
        if ($current.Count -gt 0) {
            $segments.Add($current.ToArray())
        }
        , $segments.ToArray()
    }

    $divisionSegments = & $getSegments $Division
    $divisionWords = @($divisionSegments | ForEach-Object { $_ })
    $meaningfulWords = @($divisionWords | Where-Object { -not $stopWords.Contains($_) })
    if ($meaningfulWords.Count -eq 0) {
        # The callers write the error; nothing is thrown so -ErrorVariable only records their error
        return
    }

    $parts = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $parts.Add($Prefix)

    $departmentSegments = @()
    if (-not [string]::IsNullOrWhiteSpace($Department)) {
        $departmentSegments = & $getSegments $Department
    }

    if ($departmentSegments.Count -gt 0) {
        # Initials of the division: all-caps words (acronyms such as IT) are kept whole, stop words are skipped
        $initials = -join @(foreach ($word in $meaningfulWords) {
                if ($word.Length -gt 1 -and $word -cmatch '^[\p{Lu}\p{Nd}]+$' -and $word -cmatch '\p{Lu}') {
                    $word
                }
                else {
                    $word.Substring(0, 1).ToUpperInvariant()
                }
            })
        $divisionName = ConvertTo-TcsPascalCaseName -Text ($divisionWords -join ' ')
        $parts.Add($initials)

        # Drop leading department segments that repeat the division ('HR - Payroll' in Human Resources)
        $index = 0
        while ($index -lt $departmentSegments.Count) {
            $segmentName = ConvertTo-TcsPascalCaseName -Text ($departmentSegments[$index] -join ' ')
            if ([string]::Equals($segmentName, $initials, [System.StringComparison]::OrdinalIgnoreCase) -or
                [string]::Equals($segmentName, $divisionName, [System.StringComparison]::OrdinalIgnoreCase)) {
                $index++
            }
            else {
                break
            }
        }
        for (; $index -lt $departmentSegments.Count; $index++) {
            $parts.Add((ConvertTo-TcsPascalCaseName -Text ($departmentSegments[$index] -join ' ')))
        }
    }
    else {
        foreach ($segment in $divisionSegments) {
            $parts.Add((ConvertTo-TcsPascalCaseName -Text ($segment -join ' ')))
        }
    }

    if ($Suffix) {
        $parts.Add($Suffix)
    }

    # Remove empty parts and a part that repeats the one before it ('SG-HR-HR')
    $result = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($part in $parts) {
        if (-not $part) {
            continue
        }
        if ($result.Count -gt 0 -and [string]::Equals($result[$result.Count - 1], $part, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $result.Add($part)
    }
    $result -join '-'
}
