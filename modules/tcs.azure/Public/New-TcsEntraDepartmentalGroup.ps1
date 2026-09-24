<#
.SYNOPSIS
    Creates a departmental security group in Microsoft Entra ID.

.DESCRIPTION
    The New-TcsEntraDepartmentalGroup function builds a group name with the same rules as
    Get-DepartmentalGroupName (see Get-Help Get-DepartmentalGroupName) and creates a security group
    with that name in Microsoft Entra ID.

    The group is looked up first. An existing group (same display name) is not created again: a
    warning is written and it is returned with Status 'Existing'. Only groups that do not exist yet
    are passed to -WhatIf/-Confirm and created.

    With -DynamicMembership the group gets the membership rule
    (user.department -eq "<Department>"), using the department as written (or the division when no
    department is given), and membershipRuleProcessingState On, so Entra ID keeps the members up to
    date. Dynamic membership groups need a Microsoft Entra ID P1 licence. The Microsoft.Entra.Groups
    New-EntraGroup (1.x) has no -MembershipRule parameter; in that case New-EntraBetaGroup from
    Microsoft.Entra.Beta.Groups is used, and the command stops with an error when neither supports it.

    With -Owner the given users or service principals are added as owners (Add-EntraGroupOwner).

    For every group an object is written to the pipeline with the properties Name, Id, Status
    (Created, Existing, Failed or WhatIf), MembershipRule and MailNickname.

    Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
    session opened with Connect-Entra that can create groups, for example the Group.ReadWrite.All scope.
    Supports -WhatIf and -Confirm.

.PARAMETER Prefix
    The first part of the group name, for example 'SG'. Cannot contain whitespace.
    Accepts pipeline input by property name.

.PARAMETER Suffix
    An optional last part of the group name, for example 'Users'. Cannot contain whitespace.
    Accepts pipeline input by property name.

.PARAMETER Division
    The division the group belongs to, for example 'Human Resources'. Accepts pipeline input by
    property name.

.PARAMETER Department
    The optional department within the division, for example 'Payroll'. Accepts pipeline input by
    property name. With -DynamicMembership this is the value matched against user.department.

.PARAMETER DynamicMembership
    Create a dynamic membership group with the rule (user.department -eq "<Department>"), or the
    division when no department is given.

.PARAMETER Owner
    Object IDs of users or service principals to add as owners of a created group.

.INPUTS
    System.Management.Automation.PSObject
    Objects with Prefix, Suffix, Division and Department properties (for example rows from Import-Csv).

.OUTPUTS
    Tcs.Azure.DepartmentalGroup
    One object for each group, with Name, Id, Status, MembershipRule and MailNickname.

.EXAMPLE
    New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'Payroll' -WhatIf

    Shows that the security group SG-HR-Payroll would be created.

.EXAMPLE
    New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Department 'Accounts Payable' -DynamicMembership -Owner $ownerId

    Creates SG-F-AccountsPayable with the rule (user.department -eq "Accounts Payable") and adds an owner.

.EXAMPLE
    Import-Csv .\departments.csv | New-TcsEntraDepartmentalGroup -Prefix 'SG' -Suffix 'Users'

    Creates one group for each row; the CSV has Division and Department columns.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Get-DepartmentalGroupName

.LINK
    https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership
#>
function New-TcsEntraDepartmentalGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType('Tcs.Azure.DepartmentalGroup')]
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
        $Department,

        [switch]
        $DynamicMembership,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $Owner
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

        $requiredCommands = @('Get-EntraGroup', 'New-EntraGroup')
        if ($Owner) {
            $requiredCommands += 'Add-EntraGroupOwner'
        }
        $prerequisiteError = Get-EntraPrerequisiteError -CommandName $MyInvocation.MyCommand.Name -RequiredCommand $requiredCommands

        # Microsoft.Entra.Groups 1.x New-EntraGroup cannot set a membership rule; the beta cmdlet can
        $createCommand = 'New-EntraGroup'
        if (-not $prerequisiteError -and $DynamicMembership) {
            $newGroupCommand = Get-Command -Name 'New-EntraGroup' -ErrorAction SilentlyContinue
            if (-not ($newGroupCommand -and $newGroupCommand.Parameters -and $newGroupCommand.Parameters.ContainsKey('MembershipRule'))) {
                if (Get-Command -Name 'New-EntraBetaGroup' -ErrorAction SilentlyContinue) {
                    $createCommand = 'New-EntraBetaGroup'
                }
                else {
                    $exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (
                        'Dynamic membership groups need a New-EntraGroup that supports -MembershipRule, or New-EntraBetaGroup. ' +
                        "Install it with 'Install-Module Microsoft.Entra.Beta.Groups -Scope CurrentUser'.")
                    $prerequisiteError = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'DynamicMembershipNotSupported', ([System.Management.Automation.ErrorCategory]::ObjectNotFound), $null
                }
            }
        }

        if ($prerequisiteError) {
            $telemetrySent = $true
            Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $prerequisiteError
            $PSCmdlet.ThrowTerminatingError($prerequisiteError)
        }
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

            $divisionText = @($Division -split '\s+' | Where-Object { $_ }) -join ' '
            $departmentText = @($Department -split '\s+' | Where-Object { $_ }) -join ' '
            $membershipRule = $null
            if ($DynamicMembership) {
                $ruleValue = if ($departmentText) { $departmentText } else { $divisionText }
                # Double quotes inside a rule value are escaped with a backtick
                $membershipRule = '(user.department -eq "' + ($ruleValue -replace '"', '`"') + '")'
            }

            $result = [pscustomobject]@{
                PSTypeName     = 'Tcs.Azure.DepartmentalGroup'
                Name           = $groupName
                Id             = $null
                Status         = $null
                MembershipRule = $membershipRule
                MailNickname   = $null
            }

            try {
                # Look up first so -WhatIf and -Confirm only cover a group that would really be created.
                # Single quotes are doubled so the name is a valid OData string literal.
                $filter = "DisplayName eq '$($groupName -replace "'", "''")'"
                $existing = @(Get-EntraGroup -Filter $filter -ErrorAction Stop)
                if ($existing.Count -gt 0) {
                    Write-Warning "Group `"$groupName`" already exists."
                    $result.Id = $existing[0].Id
                    $result.MailNickname = $existing[0].MailNickname
                    $result.MembershipRule = $existing[0].MembershipRule
                    $result.Status = 'Existing'
                    $result
                    $completed = $true
                    return
                }

                $result.MailNickname = ConvertTo-TcsMailNickname -Text $groupName -HashSource $groupName
                if (-not $PSCmdlet.ShouldProcess($groupName, 'Create Entra ID security group')) {
                    if ($WhatIfPreference) {
                        $result.Status = 'WhatIf'
                        $result
                    }
                    $completed = $true
                    return
                }

                $description = if ($departmentText) { "Security group for the $departmentText department of $divisionText." } else { "Security group for $divisionText." }
                $groupParams = @{
                    DisplayName     = $groupName
                    MailNickname    = $result.MailNickname
                    Description     = $description
                    MailEnabled     = $false
                    SecurityEnabled = $true
                }
                if ($DynamicMembership) {
                    $groupParams['GroupTypes'] = @('DynamicMembership')
                    $groupParams['MembershipRule'] = $membershipRule
                    $groupParams['MembershipRuleProcessingState'] = 'On'
                }
                Write-Verbose "Creating group `"$groupName`" with $createCommand"
                $group = & $createCommand @groupParams -ErrorAction Stop
                $result.Id = $group.Id
                $result.Status = 'Created'
            }
            catch [System.Management.Automation.PipelineStoppedException] {
                throw
            }
            catch {
                $lastError = $_
                $result.Status = 'Failed'
                $result
                Write-Error -ErrorRecord $_
                $completed = $true
                return
            }

            foreach ($ownerId in $Owner) {
                try {
                    Add-EntraGroupOwner -GroupId $result.Id -OwnerId $ownerId -ErrorAction Stop
                }
                catch {
                    $lastError = $_
                    Write-Error -ErrorRecord $_
                }
            }
            $result
            $completed = $true
        }
        catch {
            # Reached when the caller asked for errors to stop (-ErrorAction Stop)
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
