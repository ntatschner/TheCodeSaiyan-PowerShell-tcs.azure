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

Describe 'New-TcsEntraDepartmentalGroup' {
    BeforeEach {
        Mock -ModuleName tcs.azure Get-EntraContext { [pscustomobject]@{ Account = 'admin@contoso.com' } }
        Mock -ModuleName tcs.azure Get-EntraGroup { }
        Mock -ModuleName tcs.azure New-EntraGroup { [pscustomobject]@{ Id = "id-$DisplayName"; DisplayName = $DisplayName } }
        Mock -ModuleName tcs.azure Add-EntraGroupOwner { }
    }

    It 'Creates a security group named with the Get-DepartmentalGroupName rules' {
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll' -Suffix 'Users' -Confirm:$false
        $result.PSObject.TypeNames | Should -Contain 'Tcs.Azure.DepartmentalGroup'
        $result.Name | Should -BeExactly 'SG-HR-Payroll-Users'
        $result.Id | Should -Be 'id-SG-HR-Payroll-Users'
        $result.Status | Should -Be 'Created'
        $result.MembershipRule | Should -BeNullOrEmpty
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly -ParameterFilter {
            $DisplayName -ceq 'SG-HR-Payroll-Users' -and $MailNickname -ceq 'SG-HR-Payroll-Users' -and $SecurityEnabled -and -not $MailEnabled -and
            -not $MembershipRule -and $Description -ceq 'Security group for the HR - Payroll department of Human Resources.'
        }
    }

    It 'Builds a dynamic membership rule from the department' {
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Department 'Accounts  Payable' -DynamicMembership -Confirm:$false
        $result.MembershipRule | Should -BeExactly '(user.department -eq "Accounts Payable")'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly -ParameterFilter {
            $MembershipRule -ceq '(user.department -eq "Accounts Payable")' -and $MembershipRuleProcessingState -eq 'On' -and $GroupTypes -contains 'DynamicMembership'
        }
    }

    It 'Uses the division in the rule when there is no department, and escapes double quotes' {
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'The "Lab"' -DynamicMembership -Confirm:$false
        $result.Name | Should -BeExactly 'SG-TheLab'
        $result.MembershipRule | Should -BeExactly '(user.department -eq "The `"Lab`"")'
    }

    It 'Uses New-EntraBetaGroup when New-EntraGroup cannot set a membership rule' {
        function global:New-EntraBetaGroup { [CmdletBinding()] param([string]$DisplayName, [string]$MailNickname, [string]$Description, [bool]$MailEnabled, [bool]$SecurityEnabled, [string[]]$GroupTypes, [string]$MembershipRule, [string]$MembershipRuleProcessingState) $null = $PSBoundParameters }
        try {
            Mock -ModuleName tcs.azure Get-Command { [pscustomobject]@{ Name = 'New-EntraGroup'; Parameters = @{ DisplayName = $null } } } -ParameterFilter { $Name -eq 'New-EntraGroup' }
            Mock -ModuleName tcs.azure New-EntraBetaGroup { [pscustomobject]@{ Id = 'beta-id' } }
            $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -DynamicMembership -Confirm:$false
            $result.Id | Should -Be 'beta-id'
            Should -Invoke -ModuleName tcs.azure New-EntraBetaGroup -Times 1 -Exactly -ParameterFilter { $MembershipRule -ceq '(user.department -eq "Finance")' }
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
        }
        finally {
            Remove-Item -Path Function:\New-EntraBetaGroup -ErrorAction SilentlyContinue
        }
    }

    It 'Stops with a clear error when dynamic membership is not supported' {
        Mock -ModuleName tcs.azure Get-Command { [pscustomobject]@{ Name = 'New-EntraGroup'; Parameters = @{ DisplayName = $null } } } -ParameterFilter { $Name -eq 'New-EntraGroup' }
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -eq 'New-EntraBetaGroup' }
        { New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -DynamicMembership -Confirm:$false } | Should -Throw '*Microsoft.Entra.Beta.Groups*'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
    }

    It 'Adds owners to a created group' {
        $null = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Owner 'owner-1', 'owner-2' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Add-EntraGroupOwner -Times 2 -Exactly -ParameterFilter { $GroupId -eq 'id-SG-Finance' }
        Should -Invoke -ModuleName tcs.azure Add-EntraGroupOwner -Times 1 -Exactly -ParameterFilter { $OwnerId -eq 'owner-2' }
    }

    It 'Writes an error but keeps the group when an owner cannot be added' {
        Mock -ModuleName tcs.azure Add-EntraGroupOwner { throw 'Owner not found' }
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Owner 'bad' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        $result.Status | Should -Be 'Created'
        ($errors | Out-String) | Should -Match 'Owner not found'
    }

    It 'Returns an existing group without creating it or adding owners' {
        Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ Id = 'existing'; MailNickname = 'nick' } }
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Owner 'owner-1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
        $result.Status | Should -Be 'Existing'
        $result.Id | Should -Be 'existing'
        $warnings | Should -Match 'already exists'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
        Should -Invoke -ModuleName tcs.azure Add-EntraGroupOwner -Times 0 -Exactly
    }

    It 'Looks the group up but creates nothing with -WhatIf' {
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -WhatIf
        $result.Status | Should -Be 'WhatIf'
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
    }

    It 'Creates one group for each piped row' {
        $rows = @(
            [pscustomobject]@{ Division = 'Finance'; Department = 'Payroll' }
            [pscustomobject]@{ Division = 'Legal'; Department = '' }
        )
        $result = $rows | New-TcsEntraDepartmentalGroup -Prefix 'SG' -Confirm:$false
        $result.Name | Should -BeExactly @('SG-F-Payroll', 'SG-Legal')
    }

    It 'Writes an InvalidDivision error for a punctuation-only division' {
        $null = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division '&' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'InvalidDivision*'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
    }

    It 'Returns a Failed object and records failed telemetry when the group cannot be created' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
        $result = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Confirm:$false -ErrorAction SilentlyContinue
        $result.Status | Should -Be 'Failed'
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
    }

    It 'Throws one clear error when there is no Connect-Entra session' {
        Mock -ModuleName tcs.azure Get-EntraContext { }
        { New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Confirm:$false } | Should -Throw '*Connect-Entra*'
    }

    It 'Records start and end telemetry' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        $null = New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
    }
}
