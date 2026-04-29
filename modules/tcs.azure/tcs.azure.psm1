#region get public and private function definition files.
$Public  = @(
    Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Exclude "*.Tests.ps1" -ErrorAction SilentlyContinue -Recurse
)
$Private = @(
    Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Exclude "*.Tests.ps1" -ErrorAction SilentlyContinue -Recurse
)
#endregion

#region load Classes before functions
$ClassFiles = @(
    Get-ChildItem -Path $PSScriptRoot\Classes\*.ps1 -Exclude "*.Tests.ps1" -ErrorAction SilentlyContinue -Recurse
)
foreach ($Class in $ClassFiles) {
    try {
        . $Class.FullName
    } catch {
        Write-Error -Message "Failed to import class at $($Class.FullName): $_"
    }
}
#endregion

#region source the files
foreach ($Function in @($Public + $Private)) {
    $FunctionPath = $Function.fullname
    try {
        . $FunctionPath
    } catch {
        Write-Error -Message "Failed to import function at $($FunctionPath): $_"
    }
}
#endregion

#region set variables visible to the module and its functions only
$Date = Get-Date -UFormat "%Y.%m.%d"
$Time = Get-Date -UFormat "%H:%M:%S"
. "$PSScriptRoot\Colors.ps1"
#endregion

#region export Public functions ($Public.BaseName) for WIP modules
Export-ModuleMember -Function $Public.Basename
#endregion

#region Module Config setup and import
try {
    $CurrentConfig = Get-ModuleConfig -CommandPath $PSCommandPath -ErrorAction Stop
}
catch {
    Write-Error "Module Import error: `n $($_.Exception.Message)"
}

$ExecutionID = [System.Guid]::NewGuid().ToString()

$TelmetryArgs = @{
    ModuleName    = $CurrentConfig.ModuleName
    ModulePath    = $CurrentConfig.ModulePath
    ModuleVersion = $MyInvocation.MyCommand.Module.Version
    ExecutionID   = $ExecutionID
    CommandName   = $MyInvocation.MyCommand.Name
    URI           = 'https://NOTYETDEFINED.com'
    ClearTimer    = $true
    Stage         = 'Module-Load'
}

if ($CurrentConfig.BasicTelemetry -eq 'True') {
    Invoke-TelemetryCollection -Minimal @TelmetryArgs
} else {
    Invoke-TelemetryCollection @TelmetryArgs
}

if ($CurrentConfig.UpdateWarning -eq 'True' -or $CurrentConfig.UpdateWarning -eq $true) {
    Get-ModuleStatus -ShowMessage -ModuleName $CurrentConfig.ModuleName -ModulePath $CurrentConfig.ModulePath
}
#endregion
