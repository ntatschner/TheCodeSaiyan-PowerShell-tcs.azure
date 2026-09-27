<#
.SYNOPSIS
    Writes a non-terminating error for a public command that runs inside Invoke-TcsCommand.

.DESCRIPTION
    Private helper. Writes the error with the command's own $PSCmdlet.WriteError(), so the error
    keeps the command's error ID (for example 'BlankName,New-IntuneAppGroup') and reaches the
    caller's -ErrorVariable, as it did before the command used Invoke-TcsCommand.

    Invoke-TcsCommand does not see errors written this way, so the caller keeps the last error and
    passes it to Complete-TcsTelemetry in its end block. When the error action is Stop, the error
    ends the command and neither the caller's catch blocks nor its end block run, so the telemetry
    run is completed as failed here, before the error is written.

.PARAMETER Cmdlet
    The $PSCmdlet of the public command.

.PARAMETER ErrorRecord
    The error to write.

.PARAMETER Telemetry
    The token from Start-TcsTelemetry of the public command.
#>
function Write-CommandError {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(Mandatory = $true)]
        [PSTypeName('Tcs.TelemetryToken')]
        [PSCustomObject]
        $Telemetry
    )

    # $ErrorActionPreference is the public command's (set by its -ErrorAction or inherited)
    if ($ErrorActionPreference -eq 'Stop') {
        Complete-TcsTelemetry -Token $Telemetry -ErrorRecord $ErrorRecord
    }
    $Cmdlet.WriteError($ErrorRecord)
}
