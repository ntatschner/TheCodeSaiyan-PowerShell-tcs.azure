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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'lastError',
        Justification = 'Set inside the Invoke-TcsCommand script block and read in the end block.')]
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
        $telemetry = Start-TcsTelemetry
        # Invoke-TcsCommand does not see errors written with Write-CommandError, so the last one is reported in the end block
        $lastError = $null

        $prerequisiteError = Get-EntraPrerequisiteError -CommandName $MyInvocation.MyCommand.Name -RequiredCommand 'Get-EntraGroup'
        if ($prerequisiteError) {
            Complete-TcsTelemetry -Token $telemetry -ErrorRecord $prerequisiteError
            $PSCmdlet.ThrowTerminatingError($prerequisiteError)
        }
    }

    process {
        Invoke-TcsCommand -Token $telemetry -ScriptBlock {
            if ($PSCmdlet.ParameterSetName -eq 'All') {
                try {
                    Find-IntuneAppGroup | ForEach-Object { ConvertTo-IntuneAppGroupObject -Group $_ }
                }
                catch [System.Management.Automation.PipelineStoppedException] {
                    throw
                }
                catch {
                    $lastError = $_
                    Write-CommandError -Cmdlet $PSCmdlet -ErrorRecord $_ -Telemetry $telemetry
                }
            }
            else {
                foreach ($appName in $Name) {
                    $pascalName = ConvertTo-TcsPascalCaseName -Text $appName
                    if (-not $pascalName) {
                        $exception = New-Object -TypeName System.ArgumentException -ArgumentList 'An application name cannot be blank or whitespace only.', 'Name'
                        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'BlankName', ([System.Management.Automation.ErrorCategory]::InvalidArgument), $appName
                        $lastError = $errorRecord
                        Write-CommandError -Cmdlet $PSCmdlet -ErrorRecord $errorRecord -Telemetry $telemetry
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
                        Write-CommandError -Cmdlet $PSCmdlet -ErrorRecord $_ -Telemetry $telemetry
                    }
                }
            }
        }
    }

    end {
        Complete-TcsTelemetry -Token $telemetry -ErrorRecord $lastError
    }
}
