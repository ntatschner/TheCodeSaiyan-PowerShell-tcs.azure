<#
.SYNOPSIS
    Creates Intune app assignment groups (for example "Available" and "Required") in Microsoft Entra ID.

.DESCRIPTION
    The New-IntuneAppGroup function creates one security group in Microsoft Entra ID for each
    application name and each assignment intent. By default the "Available" and "Required" groups are
    created; use -Intent to choose (Available, Required, Uninstall).

    Groups are named 'Intune-AG-<Name>-<Intent>' (app groups) or 'Intune-ACG-<Name>-<Intent>' (app
    collection groups, with -Collection). The name is written in PascalCase with spaces removed: the
    first letter of each word is upper-cased (culture-independent) and the rest is kept, for example
    'company portal' becomes 'CompanyPortal' and '7-zip' stays '7-zip'. The description is
    'Intune <Intent> assignment group for <Name>.'

    The mail nickname is the group name made valid for Entra ID: accents are removed (an A with an umlaut becomes A),
    characters Entra ID does not allow are removed, a name with no usable characters left gets a
    short stable hash instead, and a nickname longer than 64 characters is shortened with a hash of
    the full group name added, so different applications keep different nicknames.

    Each group is looked up first. An existing group (same display name) is not created again: a
    warning is written and it is returned with Status 'Existing'. Only groups that do not exist yet
    are passed to -WhatIf/-Confirm and created.

    For every group an object is written to the pipeline with the properties Name, Id, AppName,
    Intent, Status (Created, Existing, Failed or WhatIf) and MailNickname. DisplayName is an alias of Name.

    Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and an
    authenticated session (Connect-Entra) with permission to create groups, for example the
    Group.ReadWrite.All scope. When Get-EntraContext shows no session, the command stops with one
    error asking you to run Connect-Entra. Supports -WhatIf and -Confirm.

.PARAMETER Name
    One or more application names. One group is created for each name and intent. Accepts pipeline
    input, and pipeline input by property name (Name, AppName or DisplayName).

.PARAMETER Intent
    The assignment intents to create groups for: Available, Required and/or Uninstall. The default is
    Available and Required.

.PARAMETER Collection
    Create app collection groups ('Intune-ACG-...') instead of app groups ('Intune-AG-...').

.INPUTS
    System.String
    Application names.

    System.Management.Automation.PSObject
    Objects with a Name, AppName or DisplayName property.

.OUTPUTS
    Tcs.Azure.IntuneAppGroup
    One object for each group, with Name, Id, AppName, Intent, Status and MailNickname.

.EXAMPLE
    New-IntuneAppGroup -Name 'App1', 'App2'

    Creates Intune-AG-App1-Available, Intune-AG-App1-Required, Intune-AG-App2-Available and
    Intune-AG-App2-Required, and returns an object for each of them.

.EXAMPLE
    New-IntuneAppGroup -Collection -Name 'office apps' -WhatIf

    Shows that Intune-ACG-OfficeApps-Available and Intune-ACG-OfficeApps-Required would be created,
    without creating them. Groups that already exist are returned with Status 'Existing'.

.EXAMPLE
    'Company Portal', '7-Zip' | New-IntuneAppGroup -Intent Required, Uninstall

    Creates the Required and Uninstall groups for both applications.

.EXAMPLE
    New-IntuneAppGroup -Name 'Company Portal' | Where-Object Status -EQ 'Created'

    Returns only the groups that were created by this run.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Get-IntuneAppGroup

.LINK
    Remove-IntuneAppGroup

.LINK
    https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup
#>
function New-IntuneAppGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType('Tcs.Azure.IntuneAppGroup')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('AppName', 'DisplayName')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [ValidateSet('Available', 'Required', 'Uninstall')]
        [string[]]
        $Intent = @('Available', 'Required'),

        [switch]
        $Collection
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

        $prerequisiteError = Get-EntraPrerequisiteError -CommandName $MyInvocation.MyCommand.Name -RequiredCommand 'Get-EntraGroup', 'New-EntraGroup'
        if ($prerequisiteError) {
            $telemetrySent = $true
            Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $prerequisiteError
            $PSCmdlet.ThrowTerminatingError($prerequisiteError)
        }

        $groupType = if ($Collection) { 'ACG' } else { 'AG' }
        # Canonical casing and order of first use; ValidateSet itself is case-insensitive
        $intents = New-Object -TypeName 'System.Collections.Generic.List[string]'
        foreach ($requestedIntent in $Intent) {
            $canonical = @('Available', 'Required', 'Uninstall') | Where-Object { [string]::Equals($_, $requestedIntent, [System.StringComparison]::OrdinalIgnoreCase) }
            if (-not $intents.Contains($canonical)) {
                $intents.Add($canonical)
            }
        }
    }

    process {
        $completed = $false
        try {
            foreach ($appName in $Name) {
                $pascalName = ConvertTo-TcsPascalCaseName -Text $appName
                if (-not $pascalName) {
                    $exception = New-Object -TypeName System.ArgumentException -ArgumentList 'An application name cannot be blank or whitespace only.', 'Name'
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'BlankName', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $appName
                    $lastError = $errorRecord
                    $PSCmdlet.WriteError($errorRecord)
                    continue
                }
                $friendlyName = @($appName -split '\s+' | Where-Object { $_ }) -join ' '

                foreach ($groupIntent in $intents) {
                    Write-Progress -Activity 'Creating Intune groups' -Status "Processing $pascalName ($groupIntent)"

                    $displayName = "Intune-$groupType-$pascalName-$groupIntent"
                    $result = [pscustomobject]@{
                        PSTypeName   = 'Tcs.Azure.IntuneAppGroup'
                        Name         = $displayName
                        Id           = $null
                        AppName      = $friendlyName
                        Intent       = $groupIntent
                        Status       = $null
                        MailNickname = $null
                    }
                    $result | Add-Member -MemberType AliasProperty -Name DisplayName -Value Name

                    try {
                        # Look up first so -WhatIf and -Confirm only cover groups that would really be created.
                        # Single quotes are doubled so the name is a valid OData string literal.
                        $filter = "DisplayName eq '$($displayName -replace "'", "''")'"
                        $existing = @(Get-EntraGroup -Filter $filter -ErrorAction Stop)
                        if ($existing.Count -gt 0) {
                            Write-Warning "Group `"$displayName`" already exists."
                            $result.Id = $existing[0].Id
                            $result.MailNickname = $existing[0].MailNickname
                            $result.Status = 'Existing'
                            $result
                            continue
                        }

                        $result.MailNickname = ConvertTo-TcsMailNickname -Text $pascalName -Prefix "Intune-$groupType-" -Suffix "-$groupIntent" -HashSource $displayName
                        if (-not $PSCmdlet.ShouldProcess($displayName, 'Create Entra ID security group')) {
                            if ($WhatIfPreference) {
                                $result.Status = 'WhatIf'
                                $result
                            }
                            continue
                        }

                        $groupParams = @{
                            DisplayName     = $displayName
                            MailNickname    = $result.MailNickname
                            Description     = "Intune $groupIntent assignment group for $friendlyName."
                            MailEnabled     = $false
                            SecurityEnabled = $true
                        }
                        Write-Verbose "Creating Intune group `"$displayName`""
                        $group = New-EntraGroup @groupParams -ErrorAction Stop
                        $result.Id = $group.Id
                        $result.Status = 'Created'
                        Write-Verbose "Group `"$displayName`" created."
                        $result
                    }
                    catch [System.Management.Automation.PipelineStoppedException] {
                        throw
                    }
                    catch {
                        $lastError = $_
                        $result.Status = 'Failed'
                        $result
                        Write-Error -ErrorRecord $_
                    }
                }
            }
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
                Write-Progress -Activity 'Creating Intune groups' -Completed
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
            Write-Progress -Activity 'Creating Intune groups' -Completed
            if ($lastError) {
                Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $lastError
            }
            else {
                Invoke-TelemetryCollection @TelemetryArgs -Stage End
            }
        }
    }
}
