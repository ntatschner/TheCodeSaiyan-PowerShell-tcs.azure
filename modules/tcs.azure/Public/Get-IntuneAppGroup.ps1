<#
.SYNOPSIS
    Gets Intune app assignment groups from Microsoft Entra ID.

.DESCRIPTION
    The Get-IntuneAppGroup function finds the groups created by New-IntuneAppGroup. With -Name it
    returns the app groups and app collection groups of those applications
    ('Intune-AG-<Name>-<Intent>' and 'Intune-ACG-<Name>-<Intent>'); the name is converted to
    PascalCase the same way as in New-IntuneAppGroup. With -All it returns every group whose name
    starts with 'Intune-AG-' or 'Intune-ACG-'.

    Groups are found with a startswith filter on the display name (all result pages). Each group is
    returned as a Tcs.Azure.IntuneAppGroup object with Name, Id, AppName, Intent, Status ('Existing')
    and MailNickname, so it can be piped to Remove-IntuneAppGroup. AppName and Intent are read from
    the group name and are empty for a group that does not follow the naming pattern.

    Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
    session opened with Connect-Entra that can read groups, for example the Group.Read.All scope.

.PARAMETER Name
    One or more application names. Accepts pipeline input.

.PARAMETER All
    Return every group whose name starts with 'Intune-AG-' or 'Intune-ACG-'.

.INPUTS
    System.String
    Application names.

.OUTPUTS
    Tcs.Azure.IntuneAppGroup

.EXAMPLE
    Get-IntuneAppGroup -Name 'Company Portal'

    Returns Intune-AG-CompanyPortal-Available, Intune-AG-CompanyPortal-Required and any other groups
    for Company Portal that exist.

.EXAMPLE
    Get-IntuneAppGroup -All | Group-Object -Property AppName

    Lists every Intune app group, grouped by application.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    New-IntuneAppGroup

.LINK
    Remove-IntuneAppGroup

.LINK
    https://learn.microsoft.com/powershell/module/microsoft.entra.groups/get-entragroup
#>
function Get-IntuneAppGroup {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType('Tcs.Azure.IntuneAppGroup')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ByName')]
        [Alias('AppName')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'All')]
        [switch]
        $All
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

        $prerequisiteError = Get-EntraPrerequisiteError -CommandName $MyInvocation.MyCommand.Name -RequiredCommand 'Get-EntraGroup'
        if ($prerequisiteError) {
            $telemetrySent = $true
            Invoke-TelemetryCollection @TelemetryArgs -Stage End -Failed $true -Exception $prerequisiteError
            $PSCmdlet.ThrowTerminatingError($prerequisiteError)
        }
    }

    process {
        $completed = $false
        try {
            if ($PSCmdlet.ParameterSetName -eq 'All') {
                try {
                    Find-IntuneAppGroup | ForEach-Object { ConvertTo-IntuneAppGroupObject -Group $_ }
                }
                catch [System.Management.Automation.PipelineStoppedException] {
                    throw
                }
                catch {
                    $lastError = $_
                    Write-Error -ErrorRecord $_
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
                        Find-IntuneAppGroup -AppName $pascalName | ForEach-Object { ConvertTo-IntuneAppGroupObject -Group $_ }
                    }
                    catch [System.Management.Automation.PipelineStoppedException] {
                        throw
                    }
                    catch {
                        $lastError = $_
                        Write-Error -ErrorRecord $_
                    }
                }
            }
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
