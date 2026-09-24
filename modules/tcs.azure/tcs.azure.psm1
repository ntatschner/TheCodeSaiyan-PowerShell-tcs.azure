#region load classes, then private and public functions
$ClassFiles = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Classes') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.Tests.ps1' })
$Private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.Tests.ps1' })
$Public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.Tests.ps1' })

foreach ($File in @($ClassFiles + $Private + $Public)) {
    try {
        . $File.FullName
    }
    catch {
        Write-Error -Message "Failed to import '$($File.FullName)': $_"
    }
}
#endregion

#region module config, load telemetry and update check (never blocks import)
try {
    $CurrentConfig = Get-ModuleConfig -CommandPath $PSCommandPath -ErrorAction Stop
    Invoke-TelemetryCollection -ModuleName $CurrentConfig.ModuleName -ModuleVersion $CurrentConfig.ModuleVersion -CommandName 'Import-Module' -ExecutionID ([guid]::NewGuid().ToString()) -Stage 'Module-Load'
    if ($CurrentConfig.UpdateWarning -eq $true) {
        $null = Get-ModuleStatus -ShowMessage -ModuleName $CurrentConfig.ModuleName -ModulePath $CurrentConfig.ModulePath -CacheHours $CurrentConfig.UpdateCheckIntervalHours
    }
}
catch {
    Write-Warning "tcs.azure configuration could not be loaded; defaults will be used. $($_.Exception.Message)"
}
#endregion

Export-ModuleMember -Function $Public.BaseName
