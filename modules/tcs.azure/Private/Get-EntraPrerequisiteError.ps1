<#
.SYNOPSIS
    Checks that the Microsoft Entra PowerShell commands are available and connected.

.DESCRIPTION
    Private helper. Returns an ErrorRecord when a required command is missing, or when
    Get-EntraContext is available and returns no context (no Connect-Entra session). Returns
    nothing when the checks pass. The caller records telemetry and throws the error.

.PARAMETER CommandName
    The name of the calling command, used in the error message.

.PARAMETER RequiredCommand
    The Microsoft Entra commands the caller needs.
#>
function Get-EntraPrerequisiteError {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter(Mandatory = $true)]
        [string[]]
        $RequiredCommand
    )

    $missingCommands = @($RequiredCommand | Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) })
    if ($missingCommands.Count -gt 0) {
        $exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (
            "$CommandName needs $($missingCommands -join ' and ') from the Microsoft Entra PowerShell module. " +
            "Install it with 'Install-Module Microsoft.Entra.Groups -Scope CurrentUser' (or 'Microsoft.Entra'), then run 'Connect-Entra -Scopes Group.ReadWrite.All'.")
        return New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'EntraModuleNotFound', ([System.Management.Automation.ErrorCategory]::ObjectNotFound), $null
    }

    # Get-EntraContext (Microsoft.Entra.Authentication) returns nothing when Connect-Entra has not been run.
    # Checking once here gives one clear error instead of a failure for every group.
    if (Get-Command -Name 'Get-EntraContext' -ErrorAction SilentlyContinue) {
        $context = $null
        try {
            $context = Get-EntraContext -ErrorAction Stop
        }
        catch {
            Write-Debug "Get-EntraContext failed: $($_.Exception.Message)"
        }
        if (-not $context) {
            $exception = New-Object -TypeName System.InvalidOperationException -ArgumentList (
                "$CommandName needs a Microsoft Entra session. Run 'Connect-Entra -Scopes Group.ReadWrite.All' first.")
            return New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'EntraNotConnected', ([System.Management.Automation.ErrorCategory]::AuthenticationError), $null
        }
    }
}
