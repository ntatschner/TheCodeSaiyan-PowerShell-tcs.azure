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

Describe 'Remove-IntuneAppGroup' {
    BeforeEach {
        Mock -ModuleName tcs.azure Get-EntraContext { [pscustomobject]@{ Account = 'admin@contoso.com' } }
        Mock -ModuleName tcs.azure Get-EntraGroup { } -ParameterFilter { $Filter -like "*'Intune-ACG-*" }
        Mock -ModuleName tcs.azure Get-EntraGroup {
            @(
                [pscustomobject]@{ Id = '1'; DisplayName = 'Intune-AG-App1-Available' }
                [pscustomobject]@{ Id = '2'; DisplayName = 'Intune-AG-App1-Required' }
                [pscustomobject]@{ Id = '3'; DisplayName = 'Intune-AG-App1-Uninstall' }
            )
        } -ParameterFilter { $Filter -like "*'Intune-AG-*" }
        Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ Id = $GroupId; DisplayName = "Intune-AG-ById-$GroupId" } } -ParameterFilter { $GroupId }
        Mock -ModuleName tcs.azure Remove-EntraGroup { }
    }

    It 'Has ConfirmImpact High' {
        $binding = (Get-Command -Name Remove-IntuneAppGroup).ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $binding.ConfirmImpact | Should -Be 'High'
        $binding.SupportsShouldProcess | Should -BeTrue
    }

    It 'Removes every group of an application' {
        Remove-IntuneAppGroup -Name 'App1' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 3 -Exactly
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -ParameterFilter { $GroupId -eq '1' } -Times 1 -Exactly
    }

    It 'Removes only the requested intents' {
        Remove-IntuneAppGroup -Name 'App1' -Intent Uninstall -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -ParameterFilter { $GroupId -eq '3' } -Times 1 -Exactly
    }

    It 'Removes nothing with -WhatIf' {
        Remove-IntuneAppGroup -Name 'App1' -WhatIf
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 0 -Exactly
    }

    It 'Writes nothing to the pipeline' {
        Remove-IntuneAppGroup -Name 'App1' -Confirm:$false | Should -BeNullOrEmpty
    }

    It 'Writes an error when no groups are found' {
        Mock -ModuleName tcs.azure Get-EntraGroup { } -ParameterFilter { $Filter }
        Remove-IntuneAppGroup -Name 'Missing' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'IntuneAppGroupNotFound*'
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 0 -Exactly
    }

    It 'Removes groups by Id' {
        Remove-IntuneAppGroup -Id 'abc', 'def' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -ParameterFilter { $GroupId -eq 'abc' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -ParameterFilter { $GroupId -eq 'def' } -Times 1 -Exactly
    }

    It 'Accepts the output of Get-IntuneAppGroup from the pipeline' {
        Get-IntuneAppGroup -Name 'App1' | Remove-IntuneAppGroup -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 3 -Exactly
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $GroupId -eq '2' } -Times 1 -Exactly
    }

    It 'Accepts application names from the pipeline' {
        'App1' | Remove-IntuneAppGroup -Intent Available -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -ParameterFilter { $GroupId -eq '1' } -Times 1 -Exactly
    }

    It 'Refuses to remove a group that is not an Intune app group' {
        Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ Id = $GroupId; DisplayName = 'Domain Admins' } } -ParameterFilter { $GroupId }
        Remove-IntuneAppGroup -Id 'xyz' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'NotAnIntuneAppGroup*'
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 0 -Exactly
    }

    It 'Continues and records failed telemetry when a group cannot be removed' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Mock -ModuleName tcs.azure Remove-EntraGroup { throw 'Insufficient privileges' } -ParameterFilter { $GroupId -eq '1' }
        Remove-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        ($errors | Out-String) | Should -Match 'Insufficient privileges'
        Should -Invoke -ModuleName tcs.azure Remove-EntraGroup -Times 3 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
    }

    It 'Throws a helpful error when the Entra commands are missing' {
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -eq 'Remove-EntraGroup' }
        { Remove-IntuneAppGroup -Name 'App1' -Confirm:$false } | Should -Throw '*Remove-EntraGroup*Install-Module*'
    }

    It 'Records start and end telemetry' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Remove-IntuneAppGroup -Name 'App1' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
    }
}
