[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'CI smoke test: progress is written to the job log.')]
param()

$moduleName = 'tcs.azure'
$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleDirectory = Join-Path -Path (Join-Path -Path $repoRoot -ChildPath 'modules') -ChildPath $moduleName
$moduleManifest = Join-Path -Path $moduleDirectory -ChildPath "$moduleName.psd1"

if (-not (Test-Path -Path $moduleManifest)) {
    throw "Module manifest not found at path: $moduleManifest"
}

# Keep the smoke test offline and away from the real user profile
$env:TCS_SKIP_UPDATE_CHECK = '1'
$env:TCS_TELEMETRY_OPTOUT = '1'
$env:TCS_CONFIG_ROOT = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "tcs-smoke-$([guid]::NewGuid().ToString('N'))"

try {
    Write-Host "Importing $moduleName from $moduleManifest" -ForegroundColor Cyan
    $importOutput = Import-Module -Name $moduleManifest -Force -ErrorAction Stop
    if ($importOutput) { throw 'Importing the module wrote to the pipeline.' }

    if (Test-Path -Path (Join-Path -Path $moduleDirectory -ChildPath 'Config.psd1')) {
        throw 'Importing the module wrote Config.psd1 into the module folder.'
    }

    $group = Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll' -Suffix 'Users'
    if ($group -ne 'SG-HR-Payroll-Users') { throw "Get-DepartmentalGroupName returned '$group' (expected 'SG-HR-Payroll-Users')." }

    $group = Get-DepartmentalGroupName -Prefix 'SG' -Division 'Sales & Marketing'
    if ($group -ne 'SG-SalesAndMarketing') { throw "Get-DepartmentalGroupName returned '$group' (expected 'SG-SalesAndMarketing')." }

    # The pre-0.2.0 name is kept as an alias
    $group = New-TcsDepartmentalGroup -Prefix 'SG' -Division 'IT'
    if ($group -ne 'SG-IT') { throw "New-TcsDepartmentalGroup returned '$group' (expected 'SG-IT')." }

    foreach ($commandName in 'New-IntuneAppGroup', 'Remove-IntuneAppGroup', 'New-TcsEntraDepartmentalGroup') {
        $command = Get-Command -Name $commandName -ErrorAction Stop
        if (-not $command.Parameters.ContainsKey('WhatIf')) { throw "$commandName does not support -WhatIf." }
    }

    $exported = @((Get-Module $moduleName).ExportedFunctions.Keys)
    $expected = @((Import-PowerShellDataFile -Path $moduleManifest).FunctionsToExport)
    $missing = $expected | Where-Object { $_ -notin $exported }
    if ($missing -or $exported.Count -ne $expected.Count) {
        throw "Exported functions do not match the manifest. Expected $($expected.Count), got $($exported.Count): $($exported -join ', ')"
    }

    $exportedAliases = @((Get-Module $moduleName).ExportedAliases.Keys)
    $expectedAliases = @((Import-PowerShellDataFile -Path $moduleManifest).AliasesToExport)
    if (Compare-Object -ReferenceObject $expectedAliases -DifferenceObject $exportedAliases) {
        throw "Exported aliases do not match the manifest: $($exportedAliases -join ', ')"
    }

    Write-Host 'All smoke tests passed successfully.' -ForegroundColor Green
}
finally {
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $env:TCS_CONFIG_ROOT -Recurse -Force -ErrorAction SilentlyContinue
}
