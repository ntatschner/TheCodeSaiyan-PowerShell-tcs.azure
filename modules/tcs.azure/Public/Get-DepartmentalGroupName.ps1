<#
.SYNOPSIS
    Builds a standardised departmental group name.

.DESCRIPTION
    The Get-DepartmentalGroupName function builds a group name from a prefix, a division, an optional
    department and an optional suffix, separated by hyphens. It only returns the name; it does not
    create anything in Microsoft Entra ID or Azure (use New-TcsEntraDepartmentalGroup for that).

    This command was called New-TcsDepartmentalGroup before version 0.2.0; that name still works as an alias.

    Naming rules:
      - '&' is read as 'and'. Apostrophes are removed ("Children's" -> 'Childrens'). Any other character
        that is not a letter, digit, space or hyphen (for example , ( ) / \ . :) is treated as a space.
      - Words are joined in PascalCase: the first letter of each word is upper-cased and the rest is kept
        as written, so acronyms stay as they are ('IT' -> 'IT', 'human resources' -> 'HumanResources').
        Culture-independent (invariant) casing is used, so the result is the same under any culture.
      - A hyphen inside a word ('E-Commerce') is kept. A hyphen on its own, or at the start or end of a
        word, separates parts of the name: 'Accounts Payable - UK' -> 'AccountsPayable-UK'. Stray
        hyphens and empty parts are dropped ('HR -' -> 'HR').
      - Without a department, the division is used in full ('SG-HumanResources').
      - With a department, the division is abbreviated to the initials of its words and the department
        is written in PascalCase ('SG-HR-Payroll'). All-caps words of 2 to 4 characters (acronyms) are
        kept whole in the initials ('IT Services' -> 'ITS'), and the words and, of, the and & are
        skipped ('Sales & Marketing' -> 'SM').
        Leading parts of the department that repeat the initials or the division ('HR - Payroll') are removed.
      - A part that repeats the part before it is not added twice ('HR' with department 'HR' -> 'SG-HR').
      - A division with no letters or digits left after clean-up (for example ',' or '&') is rejected
        with an error.

.PARAMETER Prefix
    The first part of the group name, for example 'SG' or 'DL'. Cannot contain whitespace.
    Accepts pipeline input by property name.

.PARAMETER Suffix
    An optional last part of the group name, for example 'Users'. Cannot contain whitespace.
    Accepts pipeline input by property name.

.PARAMETER Division
    The division the group belongs to, for example 'Human Resources'. Accepts pipeline input by
    property name, so a CSV with a Division column can be piped in.

.PARAMETER Department
    The optional department within the division, for example 'Payroll'. When supplied, the division is
    abbreviated to its initials. Accepts pipeline input by property name.

.INPUTS
    System.Management.Automation.PSObject
    Objects with Prefix, Suffix, Division and Department properties (for example rows from Import-Csv).

.OUTPUTS
    System.String

.EXAMPLE
    Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources'

    Returns 'SG-HumanResources'.

.EXAMPLE
    Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users'

    Returns 'SG-HR-PayrollAndBenefits-Users'.

.EXAMPLE
    Import-Csv .\departments.csv | Get-DepartmentalGroupName -Prefix 'SG'

    Returns one name for each row; the CSV has Division and Department columns.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan
#>
function Get-DepartmentalGroupName {
    [CmdletBinding()]
    [Alias('New-TcsDepartmentalGroup')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\S+$')]
        [string]
        $Prefix,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^\S*$')]
        [string]
        $Suffix,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Division,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $Department
    )

    begin {
        $TelemetryArgs = @{
            ModuleName    = $MyInvocation.MyCommand.Module.Name
            ModuleVersion = [string]$MyInvocation.MyCommand.Module.Version
            CommandName   = $MyInvocation.MyCommand.Name
            ExecutionID   = [guid]::NewGuid().ToString()
        }
        Invoke-TelemetryCollection @TelemetryArgs -Stage Start -ClearTimer
        $lastError = $null
        $telemetrySent = $false
    }

    process {
        $completed = $false
        try {
            $groupName = ConvertTo-DepartmentalGroupName -Prefix $Prefix -Division $Division -Department $Department -Suffix $Suffix
            if (-not $groupName) {
                $exception = New-Object -TypeName System.ArgumentException -ArgumentList (
                    "The division '$Division' contains no letters or digits that can be used in a group name.", 'Division')
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'InvalidDivision', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $Division
                $lastError = $errorRecord
                $PSCmdlet.WriteError($errorRecord)
                $completed = $true
                return
            }
            $groupName
            $completed = $true
        }
        catch {
            $lastError = $_
            throw
        }
        finally {
            # The end block does not run after a terminating error or when a downstream command
            # (for example Select-Object -First) stops the pipeline, so End telemetry is sent here.
            if (-not $completed -and -not $telemetrySent) {
                $telemetrySent = $true
                if ($lastError) {
                    Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $lastError
                }
                else {
                    Invoke-TelemetryCollection @TelemetryArgs -Stage End
                }
            }
        }
    }

    end {
        if (-not $telemetrySent) {
            $telemetrySent = $true
            if ($lastError) {
                Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $lastError
            }
            else {
                Invoke-TelemetryCollection @TelemetryArgs -Stage End
            }
        }
    }
}
