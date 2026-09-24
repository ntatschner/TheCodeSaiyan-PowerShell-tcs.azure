BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.azure.psd1') -Force
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/EntraStubs.ps1')
    $script:CreatedStubs = Add-TcsEntraStub
}

AfterAll {
    Remove-TcsEntraStub -Name $script:CreatedStubs
    Remove-Module -Name tcs.azure -Force -ErrorAction SilentlyContinue
}

Describe 'Get-IntuneAppGroup' {
    BeforeEach {
        Mock -ModuleName tcs.azure Get-EntraContext { [pscustomobject]@{ Account = 'admin@contoso.com' } }
        Mock -ModuleName tcs.azure Get-EntraGroup {
            @(
                [pscustomobject]@{ Id = '1'; DisplayName = 'Intune-AG-CompanyPortal-Available'; MailNickname = 'n1' }
                [pscustomobject]@{ Id = '2'; DisplayName = 'Intune-AG-CompanyPortal-Required'; MailNickname = 'n2' }
                [pscustomobject]@{ Id = '3'; DisplayName = 'Intune-AG-CompanyPortal-Extra-Available'; MailNickname = 'n3' }
            )
        } -ParameterFilter { $Filter -like "*'Intune-AG-*" }
        Mock -ModuleName tcs.azure Get-EntraGroup {
            [pscustomobject]@{ Id = '4'; DisplayName = 'Intune-ACG-OfficeApps-Uninstall'; MailNickname = 'n4' }
        } -ParameterFilter { $Filter -like "*'Intune-ACG-*" }
    }

    It 'Queries both prefixes with a startswith filter for the PascalCase name, all pages' {
        $null = Get-IntuneAppGroup -Name 'company portal'
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "startswith(displayName,'Intune-AG-CompanyPortal-')" -and $All } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "startswith(displayName,'Intune-ACG-CompanyPortal-')" -and $All } -Times 1 -Exactly
    }

    It 'Returns only groups that exactly match the application name' {
        $result = Get-IntuneAppGroup -Name 'Company Portal'
        $result.Name | Should -Be @('Intune-AG-CompanyPortal-Available', 'Intune-AG-CompanyPortal-Required')
        $result[0].PSObject.TypeNames | Should -Contain 'Tcs.Azure.IntuneAppGroup'
        $result[0].Id | Should -Be '1'
        $result[0].AppName | Should -Be 'CompanyPortal'
        $result[0].Intent | Should -Be 'Available'
        $result[0].Status | Should -Be 'Existing'
        $result[0].MailNickname | Should -Be 'n1'
    }

    It 'Returns every Intune app group with -All' {
        $result = Get-IntuneAppGroup -All
        $result.Name | Should -Be @('Intune-AG-CompanyPortal-Available', 'Intune-AG-CompanyPortal-Required', 'Intune-AG-CompanyPortal-Extra-Available', 'Intune-ACG-OfficeApps-Uninstall')
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "startswith(displayName,'Intune-AG-')" -and $All } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "startswith(displayName,'Intune-ACG-')" -and $All } -Times 1 -Exactly
        ($result | Where-Object Name -EQ 'Intune-ACG-OfficeApps-Uninstall').Intent | Should -Be 'Uninstall'
    }

    It 'Accepts names from the pipeline' {
        $result = 'Office Apps' | Get-IntuneAppGroup
        $result.Name | Should -Be 'Intune-ACG-OfficeApps-Uninstall'
    }

    It 'Escapes single quotes in the filter' {
        $null = Get-IntuneAppGroup -Name "O'Brien"
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "startswith(displayName,'Intune-AG-O''Brien-')" } -Times 1 -Exactly
    }

    It 'Writes an error for a blank name' {
        $null = Get-IntuneAppGroup -Name ' ' -ErrorVariable errors -ErrorAction SilentlyContinue
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'BlankName*'
    }

    It 'Writes a non-terminating error and records failed telemetry when the lookup fails' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Mock -ModuleName tcs.azure Get-EntraGroup { throw 'Forbidden' } -ParameterFilter { $Filter }
        $null = Get-IntuneAppGroup -Name 'App1' -ErrorVariable errors -ErrorAction SilentlyContinue
        ($errors | Out-String) | Should -Match 'Forbidden'
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
    }

    It 'Throws one clear error when there is no Connect-Entra session' {
        Mock -ModuleName tcs.azure Get-EntraContext { }
        { Get-IntuneAppGroup -All } | Should -Throw '*Connect-Entra*'
    }

    It 'Records start and end telemetry' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        $null = Get-IntuneAppGroup -All
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
    }

    It 'Records end telemetry when a downstream command stops the pipeline early' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        $result = Get-IntuneAppGroup -All | Select-Object -First 1
        $result.Name | Should -Be 'Intune-AG-CompanyPortal-Available'
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' } -Times 1 -Exactly
    }
}
