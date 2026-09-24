BeforeDiscovery {
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModuleRoot = Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.azure'
    $PublicFunctions = @(Get-ChildItem -Path (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' | ForEach-Object BaseName | ForEach-Object { @{ Name = $_ } })
}

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModuleRoot = Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.azure'
    $ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'tcs.azure.psd1'
    Import-Module -Name $ManifestPath -Force -ErrorVariable importErrors
    $Module = Get-Module -Name tcs.azure
}

AfterAll {
    Remove-Module -Name tcs.azure -Force -ErrorAction SilentlyContinue
}

Describe 'tcs.azure module' {
    It 'Has a valid manifest' {
        { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Imports without errors' {
        $importErrors.Count | Should -Be 0
    }

    It 'Exports exactly the functions in Public/ and listed in the manifest' {
        $publicFiles = Get-ChildItem -Path (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' | ForEach-Object BaseName | Sort-Object
        $manifestExports = (Import-PowerShellDataFile -Path $ManifestPath).FunctionsToExport | Sort-Object
        $manifestExports | Should -Be $publicFiles
        ($Module.ExportedFunctions.Keys | Sort-Object) | Should -Be $publicFiles
    }

    It 'Exports exactly the aliases listed in the manifest' {
        $manifestAliases = @((Import-PowerShellDataFile -Path $ManifestPath).AliasesToExport | Sort-Object)
        @($Module.ExportedAliases.Keys | Sort-Object) | Should -Be $manifestAliases
        $Module.ExportedAliases['New-TcsDepartmentalGroup'].ResolvedCommandName | Should -Be 'Get-DepartmentalGroupName'
    }

    It 'Uses tcs.azure.psm1 as the root module' {
        (Import-PowerShellDataFile -Path $ManifestPath).RootModule | Should -Be 'tcs.azure.psm1'
        $Module.ModuleType | Should -Be 'Script'
    }

    It 'Requires tcs.core 0.3.0 or later' {
        $required = @((Import-PowerShellDataFile -Path $ManifestPath).RequiredModules) | Where-Object { $_.ModuleName -eq 'tcs.core' }
        [version]$required.ModuleVersion | Should -BeGreaterOrEqual ([version]'0.3.0')
    }

    It 'Does not write files into the module folder when imported' {
        $before = @(Get-ChildItem -Path $ModuleRoot -Recurse -File | ForEach-Object FullName | Sort-Object)
        Import-Module -Name $ManifestPath -Force
        $after = @(Get-ChildItem -Path $ModuleRoot -Recurse -File | ForEach-Object FullName | Sort-Object)
        $after | Should -Be $before
        Join-Path -Path $ModuleRoot -ChildPath 'Config.psd1' | Should -Not -Exist
    }

    It 'Does not write to the pipeline when imported' {
        $output = & (Get-Command pwsh, powershell -ErrorAction SilentlyContinue | Select-Object -First 1).Source -NoProfile -NonInteractive -Command "`$env:TCS_CONFIG_ROOT='$($env:TCS_CONFIG_ROOT)'; `$env:TCS_SKIP_UPDATE_CHECK='1'; Import-Module '$ManifestPath' 6>`$null; 'done'"
        $output | Should -Be 'done'
    }
}

Describe 'Help for <Name>' -ForEach $PublicFunctions {
    BeforeAll {
        $help = Get-Help -Name $Name -Full
    }

    It 'Has a synopsis' {
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Synopsis | Should -Not -Match "^\s*$Name\s"
    }

    It 'Has a description' {
        ($help.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty
    }

    It 'Has at least one example' {
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }

    It 'Documents every parameter' {
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $parameters = (Get-Command -Name $Name).Parameters.Keys | Where-Object { $_ -notin $common }
        foreach ($parameter in $parameters) {
            $parameterHelp = $help.Parameters.Parameter | Where-Object Name -EQ $parameter
            ($parameterHelp.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty -Because "parameter '$parameter' should be documented"
        }
    }
}

Describe 'Telemetry coverage for <Name>' -ForEach $PublicFunctions {
    # Guard: every exported command must report start and end usage telemetry through tcs.core.
    BeforeAll {
        $definition = (Get-Command -Name $Name -Module tcs.azure).Definition
    }

    It 'Sends Start telemetry' {
        $definition | Should -Match 'Invoke-TelemetryCollection\b[^\r\n]*-Stage\s+Start'
    }

    It 'Sends End telemetry' {
        $definition | Should -Match 'Invoke-TelemetryCollection\b[^\r\n]*-Stage\s+End'
    }
}

Describe 'PSScriptAnalyzer' -Skip:(-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    It 'Reports no findings with the repository settings' {
        $settings = Join-Path -Path $RepoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
        # Pester files are excluded: PSScriptAnalyzer cannot follow Pester's block scoping.
        # Files are analysed one at a time and retried once, because PSScriptAnalyzer can throw an
        # intermittent internal NullReferenceException; an error that persists fails the test.
        $files = Get-ChildItem -Path $ModuleRoot -Recurse -Include '*.ps1', '*.psm1', '*.psd1' | Where-Object { $_.Name -notlike '*.Tests.ps1' }
        $findings = foreach ($file in $files) {
            try {
                Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settings -ErrorAction Stop
            }
            catch {
                Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settings -ErrorAction Stop
            }
        }
        $findings | ForEach-Object { Write-Host "$($_.ScriptName):$($_.Line) $($_.RuleName) $($_.Message)" }
        @($findings).Count | Should -Be 0
    }
}
