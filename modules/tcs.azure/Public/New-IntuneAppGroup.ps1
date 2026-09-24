<#
.SYNOPSIS
    Creates Intune app assignment groups ("Available" and "Required") in Microsoft Entra ID.

.DESCRIPTION
    The New-IntuneAppGroup function creates two security groups in Microsoft Entra ID for each
    application name: one for "Available" and one for "Required" Intune assignments.

    Groups are named 'Intune-AG-<Name>-<Intent>' (app groups) or 'Intune-ACG-<Name>-<Intent>' (app
    collection groups, with -Collection). The name is converted to PascalCase with spaces removed,
    for example 'company portal' becomes 'CompanyPortal'. The mail nickname is the group name with
    characters that Entra ID does not allow in a mail nickname removed.

    A group that already exists (same display name) is skipped with a warning. The created group objects
    are written to the pipeline.

    Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and an
    authenticated session (Connect-Entra) with permission to create groups, for example the
    Group.ReadWrite.All scope. Supports -WhatIf and -Confirm.

.PARAMETER Name
    One or more application names. Two groups ("Available" and "Required") are created for each name.

.PARAMETER Collection
    Create app collection groups ('Intune-ACG-...') instead of app groups ('Intune-AG-...').

.INPUTS
    None
    This function does not accept pipeline input.

.OUTPUTS
    System.Object
    The group objects returned by New-EntraGroup.

.EXAMPLE
    New-IntuneAppGroup -Name 'App1', 'App2'

    Creates Intune-AG-App1-Available, Intune-AG-App1-Required, Intune-AG-App2-Available and
    Intune-AG-App2-Required.

.EXAMPLE
    New-IntuneAppGroup -Collection -Name 'office apps' -WhatIf

    Shows that Intune-ACG-OfficeApps-Available and Intune-ACG-OfficeApps-Required would be created,
    without creating them.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup
#>
function New-IntuneAppGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [switch]
        $Collection
    )

    $TelemetryArgs = @{
        ModuleName    = $MyInvocation.MyCommand.Module.Name
        ModuleVersion = [string]$MyInvocation.MyCommand.Module.Version
        CommandName   = $MyInvocation.MyCommand.Name
        ExecutionID   = [guid]::NewGuid().ToString()
    }
    Invoke-TelemetryCollection @TelemetryArgs -Stage Start -ClearTimer

    $missingCommands = @('Get-EntraGroup', 'New-EntraGroup' | Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) })
    if ($missingCommands.Count -gt 0) {
        $exception = [System.Management.Automation.CommandNotFoundException]::new(
            "New-IntuneAppGroup needs $($missingCommands -join ' and ') from the Microsoft Entra PowerShell module. " +
            "Install it with 'Install-Module Microsoft.Entra.Groups -Scope CurrentUser' (or 'Microsoft.Entra'), then run 'Connect-Entra -Scopes Group.ReadWrite.All'.")
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'EntraModuleNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $null)
        Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $errorRecord
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $groupType = if ($Collection) { 'ACG' } else { 'AG' }
    $groupKind = if ($Collection) { 'App Collection Group' } else { 'App Group' }
    $totalIterations = $Name.Count * 2
    $currentIteration = 0
    $lastError = $null

    try {
        foreach ($appName in $Name) {
            $words = @($appName -split '\s+' | Where-Object { $_ })
            $appName = ($words | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
            if (-not $appName) {
                $currentIteration += 2
                Write-Error -Message 'An application name cannot be blank or whitespace only.' -Category InvalidArgument -ErrorId 'BlankName'
                continue
            }
            $description = "Intune $groupKind for `"$appName`", this is an"

            foreach ($intent in @('Available', 'Required')) {
                $currentIteration++
                Write-Progress -Activity 'Creating Intune Groups' -Status "Processing $appName ($intent)" -PercentComplete (($currentIteration / $totalIterations) * 100)

                $displayName = "Intune-$groupType-$appName-$intent"
                if (-not $PSCmdlet.ShouldProcess($displayName, 'Create Entra ID security group')) {
                    continue
                }

                try {
                    # Single quotes are doubled so the name is a valid OData string literal
                    $filter = "DisplayName eq '$($displayName -replace "'", "''")'"
                    if (Get-EntraGroup -Filter $filter -ErrorAction Stop) {
                        Write-Warning "Group `"$displayName`" already exists."
                        continue
                    }

                    $groupParams = @{
                        DisplayName     = $displayName
                        # Entra ID mail nicknames cannot contain spaces, non-ASCII characters or @ ( ) \ [ ] " ; : < > ,
                        MailNickname    = $displayName -replace '[^\x21-\x7E]|[@()\\\[\]";:<>,]', ''
                        Description     = "$description $intent install."
                        MailEnabled     = $false
                        SecurityEnabled = $true
                    }
                    Write-Verbose "Creating Intune group `"$displayName`""
                    New-EntraGroup @groupParams -ErrorAction Stop
                    Write-Verbose "Group `"$displayName`" created."
                }
                catch {
                    $lastError = $_
                    Write-Error -ErrorRecord $_
                }
            }
        }
    }
    catch {
        # Reached when the caller asked for errors to stop (-ErrorAction Stop)
        $lastError = $_
        throw
    }
    finally {
        Write-Progress -Activity 'Creating Intune Groups' -Completed
        if ($lastError) {
            Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $lastError
        }
        else {
            Invoke-TelemetryCollection @TelemetryArgs -Stage End
        }
    }
}
