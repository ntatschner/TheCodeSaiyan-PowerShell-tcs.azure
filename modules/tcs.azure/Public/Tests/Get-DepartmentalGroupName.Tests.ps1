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

Describe 'Get-DepartmentalGroupName' {
    Context 'Division only' {
        It 'Returns <Expected> for division <Division>' -ForEach @(
            @{ Division = 'Finance'; Expected = 'SG-Finance' }
            @{ Division = 'human resources'; Expected = 'SG-HumanResources' }
            @{ Division = 'Sales & Marketing'; Expected = 'SG-SalesAndMarketing' }
            @{ Division = 'Legal, Risk  and Compliance '; Expected = 'SG-LegalRiskAndCompliance' }
            @{ Division = 'IT'; Expected = 'SG-IT' }
            @{ Division = 'HR'; Expected = 'SG-HR' }
            @{ Division = 'HR -'; Expected = 'SG-HR' }
            @{ Division = '- HR -'; Expected = 'SG-HR' }
            @{ Division = 'Accounts Payable - UK'; Expected = 'SG-AccountsPayable-UK' }
            @{ Division = 'Accounts Payable -- UK'; Expected = 'SG-AccountsPayable-UK' }
            @{ Division = 'Research (R/D)'; Expected = 'SG-ResearchRD' }
            @{ Division = 'Sales/Marketing'; Expected = 'SG-SalesMarketing' }
            @{ Division = "Children's Services"; Expected = 'SG-ChildrensServices' }
            @{ Division = 'E-Commerce'; Expected = 'SG-E-Commerce' }
        ) {
            Get-DepartmentalGroupName -Prefix 'SG' -Division $Division | Should -BeExactly $Expected
        }

        It 'Appends the suffix' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Finance' -Suffix 'Users' | Should -BeExactly 'SG-Finance-Users'
        }
    }

    Context 'Division and department' {
        It 'Abbreviates the division and PascalCases the department' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'payroll' | Should -BeExactly 'SG-HR-Payroll'
        }

        It 'Removes a leading division abbreviation from the department' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users' |
                Should -BeExactly 'SG-HR-PayrollAndBenefits-Users'
        }

        It 'Does not remove the abbreviation from the middle of the department' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'Shr - Team' | Should -BeExactly 'SG-HR-Shr-Team'
        }

        It 'Handles repeated and trailing spaces without failing' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human  Resources ' -Department ' Talent   Acquisition ' | Should -BeExactly 'SG-HR-TalentAcquisition'
        }

        It 'Treats a whitespace-only department as no department' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Finance' -Department '  ' | Should -BeExactly 'SG-Finance'
        }

        It 'Returns <Expected> for division <Division> and department <Department>' -ForEach @(
            @{ Division = 'Sales & Marketing'; Department = 'Digital'; Expected = 'SG-SM-Digital' }
            @{ Division = 'Department of the Treasury'; Department = 'Audit'; Expected = 'SG-DT-Audit' }
            @{ Division = 'IT'; Department = 'Service Desk'; Expected = 'SG-IT-ServiceDesk' }
            @{ Division = 'IT Services'; Department = 'Service Desk'; Expected = 'SG-ITS-ServiceDesk' }
            @{ Division = 'Human Resources'; Department = 'HR'; Expected = 'SG-HR' }
            @{ Division = 'HR'; Department = 'HR -'; Expected = 'SG-HR' }
            @{ Division = 'Human Resources'; Department = 'Human Resources - Payroll'; Expected = 'SG-HR-Payroll' }
            @{ Division = 'Finance'; Department = 'Accounts Payable - UK'; Expected = 'SG-F-AccountsPayable-UK' }
            @{ Division = 'Finance'; Department = 'Payroll (UK/IE)'; Expected = 'SG-F-PayrollUKIE' }
            @{ Division = 'Finance'; Department = ','; Expected = 'SG-Finance' }
        ) {
            Get-DepartmentalGroupName -Prefix 'SG' -Division $Division -Department $Department | Should -BeExactly $Expected
        }
    }

    Context 'Invalid division' {
        It 'Rejects division <Division> with a clear error' -ForEach @(
            @{ Division = ',' }
            @{ Division = '&' }
            @{ Division = ' - ' }
            @{ Division = '()' }
        ) {
            { Get-DepartmentalGroupName -Prefix 'SG' -Division $Division -ErrorAction Stop } | Should -Throw '*contains no letters or digits*'
        }

        It 'Writes a non-terminating error with the InvalidDivision id and returns nothing' {
            $result = Get-DepartmentalGroupName -Prefix 'SG' -Division ',' -ErrorVariable errors -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $errors[0].FullyQualifiedErrorId | Should -BeLike 'InvalidDivision*'
        }

        It 'Records failed end telemetry for an invalid division' {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
            $null = Get-DepartmentalGroupName -Prefix 'SG' -Division '&' -ErrorAction SilentlyContinue
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
        }
    }

    Context 'Culture' {
        BeforeAll {
            $script:OriginalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
        }

        AfterEach {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $script:OriginalCulture
        }

        It 'Uses invariant casing under tr-TR' {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('tr-TR')
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'information technology' -Department 'identity' | Should -BeExactly 'SG-IT-Identity'
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'internal audit' | Should -BeExactly 'SG-InternalAudit'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts Division, Department, Prefix and Suffix by property name' {
            $rows = @(
                [pscustomobject]@{ Prefix = 'SG'; Division = 'Finance'; Department = 'Payroll'; Suffix = 'Users' }
                [pscustomobject]@{ Prefix = 'DL'; Division = 'Human Resources'; Department = '' }
            )
            $rows | Get-DepartmentalGroupName | Should -BeExactly @('SG-F-Payroll-Users', 'DL-HumanResources')
        }

        It 'Takes the prefix from the command line for piped rows' {
            @([pscustomobject]@{ Division = 'Finance' }, [pscustomobject]@{ Division = 'Legal' }) | Get-DepartmentalGroupName -Prefix 'SG' |
                Should -BeExactly @('SG-Finance', 'SG-Legal')
        }

        It 'Continues with the next row after an invalid division' {
            $result = @([pscustomobject]@{ Division = ',' }, [pscustomobject]@{ Division = 'Legal' }) |
                Get-DepartmentalGroupName -Prefix 'SG' -ErrorAction SilentlyContinue
            $result | Should -BeExactly 'SG-Legal'
        }
    }

    Context 'Telemetry' {
        BeforeEach {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        }

        It 'Records start and end telemetry and returns only the name' {
            $result = @(Get-DepartmentalGroupName -Prefix 'SG' -Division 'Finance')
            $result | Should -BeExactly @('SG-Finance')
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' -and $CommandName -eq 'Get-DepartmentalGroupName' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Failed } -Times 0 -Exactly
        }

        It 'Records one start and one end for a piped batch' {
            $null = @('Finance', 'Legal', 'Sales') | ForEach-Object { [pscustomobject]@{ Division = $_ } } | Get-DepartmentalGroupName -Prefix 'SG'
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' } -Times 1 -Exactly
        }

        It 'Records end telemetry when a downstream command stops the pipeline early' {
            $result = @('Finance', 'Legal', 'Sales') | ForEach-Object { [pscustomobject]@{ Division = $_ } } |
                Get-DepartmentalGroupName -Prefix 'SG' | Select-Object -First 1
            $result | Should -BeExactly 'SG-Finance'
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
        }
    }

    Context 'Parameter validation' {
        It 'Rejects a prefix containing whitespace' {
            { Get-DepartmentalGroupName -Prefix 'S G' -Division 'Finance' } | Should -Throw
        }

        It 'Rejects a suffix containing whitespace' {
            { Get-DepartmentalGroupName -Prefix 'SG' -Division 'Finance' -Suffix 'All Users' } | Should -Throw
        }

        It 'Rejects an empty division' {
            { Get-DepartmentalGroupName -Prefix 'SG' -Division '' } | Should -Throw
        }

        It 'Returns a string' {
            Get-DepartmentalGroupName -Prefix 'SG' -Division 'Finance' | Should -BeOfType [string]
        }

        It 'Is not flagged as state changing (no ShouldProcess needed)' {
            (Get-Command -Name Get-DepartmentalGroupName).Verb | Should -Be 'Get'
        }
    }

    Context 'New-TcsDepartmentalGroup alias' {
        It 'Is exported as an alias of Get-DepartmentalGroupName' {
            $alias = Get-Command -Name New-TcsDepartmentalGroup
            $alias.CommandType | Should -Be 'Alias'
            $alias.ResolvedCommand.Name | Should -Be 'Get-DepartmentalGroupName'
        }

        It 'Still returns the same names' {
            New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'Payroll' | Should -BeExactly 'SG-HR-Payroll'
        }
    }
}
