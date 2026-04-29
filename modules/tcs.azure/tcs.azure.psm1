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
$CurrentConfig = Get-ModuleConfig
if ($CurrentConfig.UpdateWarning -eq 'True' -or $CurrentConfig.UpdateWarning -eq $true) {
    Get-ModuleStatus -ShowMessage -ModuleName $CurrentConfig.ModuleName -ModulePath $CurrentConfig.ModulePath
}
#endregion
