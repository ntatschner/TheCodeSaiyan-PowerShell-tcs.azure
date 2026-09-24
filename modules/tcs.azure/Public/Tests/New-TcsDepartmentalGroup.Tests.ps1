BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.azure.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.azure -Force -ErrorAction SilentlyContinue
}

Describe 'New-TcsDepartmentalGroup' {
    Context 'Division only' {
        It 'Returns <Expected> for division <Division>' -ForEach @(
            @{ Division = 'Finance'; Expected = 'SG-Finance' }
            @{ Division = 'human resources'; Expected = 'SG-HumanResources' }
            @{ Division = 'Sales & Marketing'; Expected = 'SG-SalesAndMarketing' }
            @{ Division = 'Legal, Risk  and Compliance '; Expected = 'SG-LegalRiskAndCompliance' }
            @{ Division = 'IT'; Expected = 'SG-It' }
        ) {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division $Division | Should -BeExactly $Expected
        }

        It 'Appends the suffix' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Suffix 'Users' | Should -BeExactly 'SG-Finance-Users'
        }
    }

    Context 'Division and department' {
        It 'Abbreviates the division and PascalCases the department' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'payroll' | Should -BeExactly 'SG-HR-Payroll'
        }

        It 'Removes a leading division abbreviation from the department' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users' |
                Should -BeExactly 'SG-HR-PayrollAndBenefits-Users'
        }

        It 'Does not remove the abbreviation from the middle of the department' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'Shr - Team' | Should -BeExactly 'SG-HR-Shr-Team'
        }

        It 'Handles repeated and trailing spaces without failing' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human  Resources ' -Department ' Talent   Acquisition ' | Should -BeExactly 'SG-HR-TalentAcquisition'
        }

        It 'Treats a whitespace-only department as no department' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Department '  ' | Should -BeExactly 'SG-Finance'
        }
    }

    Context 'Telemetry' {
        It 'Records start and end telemetry and returns only the name' {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
            $result = @(New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Finance')
            $result | Should -BeExactly @('SG-Finance')
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' -and $CommandName -eq 'New-TcsDepartmentalGroup' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Failed } -Times 0 -Exactly
        }
    }

    Context 'Parameter validation' {
        It 'Rejects a prefix containing whitespace' {
            { New-TcsDepartmentalGroup -Prefix 'S G' -Division 'Finance' } | Should -Throw
        }

        It 'Rejects a suffix containing whitespace' {
            { New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Suffix 'All Users' } | Should -Throw
        }

        It 'Rejects an empty division' {
            { New-TcsDepartmentalGroup -Prefix 'SG' -Division '' } | Should -Throw
        }

        It 'Returns a string' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Finance' | Should -BeOfType [string]
        }
    }
}
