<#
.SYNOPSIS
    Deletes Intune app assignment groups from Microsoft Entra ID.

.DESCRIPTION
    The Remove-IntuneAppGroup function deletes the groups created by New-IntuneAppGroup.

    With -Name, the app groups and app collection groups of those applications are found the same
    way as Get-IntuneAppGroup -Name does; use -Intent to delete only some of them. With -Id (or by
    piping the output of Get-IntuneAppGroup or New-IntuneAppGroup), the groups with those object IDs
    are deleted. A group whose name does not start with 'Intune-AG-' or 'Intune-ACG-' is never
    deleted; an error is written instead.

    Deleted security groups cannot be restored. ConfirmImpact is High, so you are asked to confirm
    each group unless you use -Confirm:$false. Supports -WhatIf. Nothing is written to the pipeline.

    Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
    session opened with Connect-Entra that can delete groups, for example the Group.ReadWrite.All scope.

.PARAMETER Name
    One or more application names whose groups are deleted. Accepts pipeline input.

.PARAMETER Intent
    With -Name, delete only the groups for these intents (Available, Required, Uninstall). By
    default the groups for every intent are deleted.

.PARAMETER Id
    The object IDs of the groups to delete. Accepts pipeline input by property name (Id, ObjectId or
    GroupId), for example from Get-IntuneAppGroup.

.INPUTS
    System.String
    Application names.

    System.Management.Automation.PSObject
    Objects with an Id property, such as the output of Get-IntuneAppGroup.

.OUTPUTS
    None

.EXAMPLE
    Remove-IntuneAppGroup -Name 'Company Portal' -WhatIf

    Shows which Company Portal groups would be deleted.

.EXAMPLE
    Remove-IntuneAppGroup -Name 'Company Portal' -Intent Uninstall -Confirm:$false

    Deletes Intune-AG-CompanyPortal-Uninstall (and Intune-ACG-CompanyPortal-Uninstall) without asking.

.EXAMPLE
    Get-IntuneAppGroup -All | Where-Object AppName -EQ 'OldApp' | Remove-IntuneAppGroup

    Deletes the groups returned by Get-IntuneAppGroup, asking for each one.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Get-IntuneAppGroup

.LINK
    New-IntuneAppGroup

.LINK
    https://learn.microsoft.com/powershell/module/microsoft.entra.groups/remove-entragroup
#>
function Remove-IntuneAppGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ByName')]
        [Alias('AppName')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateSet('Available', 'Required', 'Uninstall')]
        [string[]]
        $Intent,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('ObjectId', 'GroupId')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Id
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

        $prerequisiteError = Get-EntraPrerequisiteError -CommandName $MyInvocation.MyCommand.Name -RequiredCommand 'Get-EntraGroup', 'Remove-EntraGroup'
        if ($prerequisiteError) {
            $telemetrySent = $true
            Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $prerequisiteError
            $PSCmdlet.ThrowTerminatingError($prerequisiteError)
        }
    }

    process {
        $completed = $false
        try {
            $groups = New-Object -TypeName 'System.Collections.Generic.List[object]'
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                foreach ($groupId in $Id) {
                    try {
                        $group = Get-EntraGroup -GroupId $groupId -ErrorAction Stop
                    }
                    catch {
                        $lastError = $_
                        Write-Error -ErrorRecord $_
                        continue
                    }
                    if (-not [regex]::IsMatch([string]$group.DisplayName, '^Intune-(AG|ACG)-', 'IgnoreCase, CultureInvariant')) {
                        $exception = New-Object -TypeName System.ArgumentException -ArgumentList "The group '$($group.DisplayName)' ($groupId) is not an Intune app group and was not deleted.", 'Id'
                        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'NotAnIntuneAppGroup', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $groupId
                        $lastError = $errorRecord
                        $PSCmdlet.WriteError($errorRecord)
                        continue
                    }
                    $groups.Add($group)
                }
            }
            else {
                foreach ($appName in $Name) {
                    $pascalName = ConvertTo-TcsPascalCaseName -Text $appName
                    if (-not $pascalName) {
                        $exception = New-Object -TypeName System.ArgumentException -ArgumentList 'An application name cannot be blank or whitespace only.', 'Name'
                        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'BlankName', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $appName
                        $lastError = $errorRecord
                        $PSCmdlet.WriteError($errorRecord)
                        continue
                    }
                    try {
                        $found = @(Find-IntuneAppGroup -AppName $pascalName)
                    }
                    catch {
                        $lastError = $_
                        Write-Error -ErrorRecord $_
                        continue
                    }
                    if ($Intent) {
                        $found = @($found | Where-Object {
                                $groupIntent = ([string]$_.DisplayName -split '-')[-1]
                                $Intent -contains $groupIntent
                            })
                    }
                    if ($found.Count -eq 0) {
                        $exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList "No Intune app groups were found for '$appName'."
                        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'IntuneAppGroupNotFound', ([System.Management.Automation.ErrorCategory]::ObjectNotFound), $appName
                        $lastError = $errorRecord
                        $PSCmdlet.WriteError($errorRecord)
                        continue
                    }
                    foreach ($group in $found) {
                        $groups.Add($group)
                    }
                }
            }

            foreach ($group in $groups) {
                if (-not $PSCmdlet.ShouldProcess("$($group.DisplayName) ($($group.Id))", 'Remove Entra ID security group')) {
                    continue
                }
                try {
                    Remove-EntraGroup -GroupId $group.Id -ErrorAction Stop
                    Write-Verbose "Group `"$($group.DisplayName)`" removed."
                }
                catch {
                    $lastError = $_
                    Write-Error -ErrorRecord $_
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
            # The end block does not run after a terminating error or when the pipeline is stopped,
            # so End telemetry is sent here.
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
