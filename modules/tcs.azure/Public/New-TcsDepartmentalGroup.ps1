<#
.SYNOPSIS
    Builds a standardised departmental group name.

.DESCRIPTION
    The New-TcsDepartmentalGroup function builds a group name from a prefix, a division, an optional
    department and an optional suffix, separated by hyphens. It only returns the name; it does not
    create anything in Microsoft Entra ID or Azure.

    Normalisation rules:
      - '&' is replaced with 'and' in the division and the department; commas are removed from the division.
      - Without a department, the division is written in PascalCase with spaces removed
        ('Human Resources' -> 'HumanResources').
      - With a department, the division is abbreviated to the upper-case initials of its words
        ('Human Resources' -> 'HR') and the department is written in PascalCase. A leading
        '<initials> -' in the department ('HR - Payroll') is removed, so the initials are not repeated.

.PARAMETER Prefix
    The first part of the group name, for example 'SG' or 'DL'. Cannot contain whitespace.

.PARAMETER Suffix
    An optional last part of the group name, for example 'Users'. Cannot contain whitespace.

.PARAMETER Division
    The division the group belongs to, for example 'Human Resources'.

.PARAMETER Department
    The optional department within the division, for example 'Payroll'. When supplied, the division is
    abbreviated to its initials.

.INPUTS
    None
    This function does not accept pipeline input.

.OUTPUTS
    System.String

.EXAMPLE
    New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources'

    Returns 'SG-HumanResources'.

.EXAMPLE
    New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users'

    Returns 'SG-HR-PayrollAndBenefits-Users'.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan
#>
function New-TcsDepartmentalGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only builds and returns a group name string; no state is changed.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\S+$')]
        [string]
        $Prefix,

        [ValidatePattern('^\S*$')]
        [string]
        $Suffix,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Division,

        [string]
        $Department
    )

    $TelemetryArgs = @{
        ModuleName    = $MyInvocation.MyCommand.Module.Name
        ModuleVersion = [string]$MyInvocation.MyCommand.Module.Version
        CommandName   = $MyInvocation.MyCommand.Name
        ExecutionID   = [guid]::NewGuid().ToString()
    }
    Invoke-TelemetryCollection @TelemetryArgs -Stage Start -ClearTimer

    try {
        # Upper-case the first letter of each word, lower-case the rest, and join the words together.
        # Words are split on any run of whitespace so repeated or trailing spaces cannot produce empty words.
        $ToPascalCase = {
            param([string]$Text)
            $words = @($Text -split '\s+' | Where-Object { $_ })
            ($words | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower() }) -join ''
        }

        $Division = ($Division -replace '&', 'and') -replace ',', ''
        $parts = @($Prefix)

        if (-not [string]::IsNullOrWhiteSpace($Department)) {
            $Department = $Department -replace '&', 'and'
            $initials = (@($Division -split '\s+' | Where-Object { $_ }) | ForEach-Object { $_.Substring(0, 1).ToUpper() }) -join ''
            $Department = $Department -replace ('^\s*' + [regex]::Escape($initials) + '\s*-'), ''
            $parts += $initials
            $parts += & $ToPascalCase $Department
        }
        else {
            $parts += & $ToPascalCase $Division
        }

        if ($Suffix) {
            $parts += $Suffix
        }

        $parts -join '-'
        Invoke-TelemetryCollection @TelemetryArgs -Stage End
    }
    catch {
        Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $_
        throw
    }
}
