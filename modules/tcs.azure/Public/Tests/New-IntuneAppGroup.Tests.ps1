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

Describe 'New-IntuneAppGroup' {
    BeforeEach {
        Mock -ModuleName tcs.azure Get-EntraContext { [pscustomobject]@{ Account = 'admin@contoso.com' } }
        Mock -ModuleName tcs.azure Get-EntraGroup { }
        Mock -ModuleName tcs.azure New-EntraGroup { [pscustomobject]@{ Id = "id-$DisplayName"; DisplayName = $DisplayName; MailNickname = $MailNickname } }
    }

    Context 'Group names and properties' {
        It 'Creates an Available and a Required app group for each name' {
            $result = New-IntuneAppGroup -Name 'App1', 'App2' -Confirm:$false
            $result.Name | Should -Be @('Intune-AG-App1-Available', 'Intune-AG-App1-Required', 'Intune-AG-App2-Available', 'Intune-AG-App2-Required')
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 4 -Exactly
        }

        It 'Returns objects with Name, Id, AppName, Intent, Status and MailNickname' {
            $result = @(New-IntuneAppGroup -Name 'Company Portal' -Confirm:$false)
            $result[0].PSObject.TypeNames | Should -Contain 'Tcs.Azure.IntuneAppGroup'
            $result[0].Name | Should -BeExactly 'Intune-AG-CompanyPortal-Available'
            $result[0].DisplayName | Should -BeExactly 'Intune-AG-CompanyPortal-Available'
            $result[0].Id | Should -Be 'id-Intune-AG-CompanyPortal-Available'
            $result[0].AppName | Should -BeExactly 'Company Portal'
            $result[0].Intent | Should -Be 'Available'
            $result[0].Status | Should -Be 'Created'
            $result[0].MailNickname | Should -BeExactly 'Intune-AG-CompanyPortal-Available'
        }

        It 'Creates security groups that are not mail enabled, with a description' {
            $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly -ParameterFilter {
                $DisplayName -eq 'Intune-AG-App1-Required' -and $SecurityEnabled -eq $true -and $MailEnabled -eq $false -and
                $Description -ceq 'Intune Required assignment group for App1.'
            }
        }

        It 'Uses the ACG prefix with -Collection' {
            $result = New-IntuneAppGroup -Name 'Office Apps' -Collection -Confirm:$false
            $result.Name | Should -Be @('Intune-ACG-OfficeApps-Available', 'Intune-ACG-OfficeApps-Required')
        }

        It 'Converts names to PascalCase and tolerates repeated spaces' {
            $result = New-IntuneAppGroup -Name 'company   portal ' -Confirm:$false
            $result[0].Name | Should -BeExactly 'Intune-AG-CompanyPortal-Available'
            $result[0].AppName | Should -BeExactly 'company portal'
        }

        It 'Keeps acronyms, mixed case and hyphenated names' {
            $result = New-IntuneAppGroup -Name 'VLC', 'PowerShell 7', '7-zip' -Intent Available -Confirm:$false
            $result.Name | Should -BeExactly @('Intune-AG-VLC-Available', 'Intune-AG-PowerShell7-Available', 'Intune-AG-7-zip-Available')
        }

        It 'Removes characters that are not valid in a mail nickname' {
            $result = New-IntuneAppGroup -Name 'App(x64)' -Confirm:$false
            $result[0].Name | Should -BeExactly 'Intune-AG-App(x64)-Available'
            $result[0].MailNickname | Should -BeExactly 'Intune-AG-Appx64-Available'
        }

        It 'Escapes single quotes in the OData filter' {
            $null = New-IntuneAppGroup -Name "O'Brien" -Confirm:$false
            Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "DisplayName eq 'Intune-AG-O''Brien-Available'" } -Times 1 -Exactly
        }
    }

    Context 'Mail nicknames' {
        It 'Keeps a long nickname within 64 characters and ends it with the intent' {
            $result = @(New-IntuneAppGroup -Name ('x' * 80) -Collection -Intent Uninstall -Confirm:$false)
            $result[0].MailNickname.Length | Should -BeLessOrEqual 64
            $result[0].MailNickname | Should -Match '^Intune-ACG-X+-[0-9a-f]{8}-Uninstall$'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -ParameterFilter { $MailNickname.Length -le 64 } -Times 1 -Exactly
        }

        It 'Gives long names that only differ at the end different nicknames' {
            $first = New-IntuneAppGroup -Name (('a' * 70) + 'One') -Intent Available -Confirm:$false
            $second = New-IntuneAppGroup -Name (('a' * 70) + 'Two') -Intent Available -Confirm:$false
            $first.MailNickname | Should -Not -Be $second.MailNickname
        }

        It 'Returns the same nickname for the same name every time' {
            $first = New-IntuneAppGroup -Name ('y' * 90) -Intent Available -Confirm:$false
            $second = New-IntuneAppGroup -Name ('y' * 90) -Intent Available -Confirm:$false
            $first.MailNickname | Should -BeExactly $second.MailNickname
        }

        It 'Removes accents from non-ASCII letters' {
            $name = -join [char[]](0xC4, 0xD6, 0xDC, 0x20, 0xE9, 0x74, 0xE9)
            $result = @(New-IntuneAppGroup -Name $name -Intent Available -Confirm:$false)
            $result[0].Name | Should -BeExactly ('Intune-AG-' + (-join [char[]](0xC4, 0xD6, 0xDC, 0xC9, 0x74, 0xE9)) + '-Available')
            $result[0].MailNickname | Should -BeExactly 'Intune-AG-AOUEte-Available'
        }

        It 'Uses a hash for names without any ASCII letters, so they do not collide' {
            $first = New-IntuneAppGroup -Name (-join [char[]](0x5FAE, 0x4FE1)) -Intent Available -Confirm:$false
            $second = New-IntuneAppGroup -Name (-join [char[]](0x9489, 0x9489)) -Intent Available -Confirm:$false
            $first.MailNickname | Should -Match '^Intune-AG-[0-9a-f]{8}-Available$'
            $second.MailNickname | Should -Match '^Intune-AG-[0-9a-f]{8}-Available$'
            $first.MailNickname | Should -Not -Be $second.MailNickname
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -ParameterFilter { $MailNickname -eq 'Intune-AG--Available' } -Times 0 -Exactly
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
            $result = @(New-IntuneAppGroup -Name 'internet explorer' -Intent Available -Confirm:$false)
            $result[0].Name | Should -BeExactly 'Intune-AG-InternetExplorer-Available'
            $result[0].MailNickname | Should -BeExactly 'Intune-AG-InternetExplorer-Available'
        }
    }

    Context 'Intent' {
        It 'Creates only the requested intents' {
            $result = New-IntuneAppGroup -Name 'App1' -Intent Uninstall -Confirm:$false
            $result.Name | Should -BeExactly 'Intune-AG-App1-Uninstall'
            $result.Intent | Should -Be 'Uninstall'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -ParameterFilter { $Description -ceq 'Intune Uninstall assignment group for App1.' } -Times 1 -Exactly
        }

        It 'Creates all three intents in the order given, once each' {
            $result = New-IntuneAppGroup -Name 'App1' -Intent required, Uninstall, Available, Required -Confirm:$false
            $result.Name | Should -BeExactly @('Intune-AG-App1-Required', 'Intune-AG-App1-Uninstall', 'Intune-AG-App1-Available')
        }

        It 'Defaults to Available and Required' {
            $result = New-IntuneAppGroup -Name 'App1' -Confirm:$false
            $result.Intent | Should -Be @('Available', 'Required')
        }

        It 'Rejects an unknown intent' {
            { New-IntuneAppGroup -Name 'App1' -Intent 'Optional' -Confirm:$false } | Should -Throw
        }
    }

    Context 'Pipeline input' {
        It 'Accepts names from the pipeline' {
            $result = 'App1', 'App2' | New-IntuneAppGroup -Intent Available -Confirm:$false
            $result.Name | Should -Be @('Intune-AG-App1-Available', 'Intune-AG-App2-Available')
        }

        It 'Accepts objects with a <Property> property' -ForEach @(
            @{ Property = 'Name' }
            @{ Property = 'AppName' }
            @{ Property = 'DisplayName' }
        ) {
            $result = [pscustomobject]@{ $Property = 'Company Portal' } | New-IntuneAppGroup -Intent Available -Confirm:$false
            $result.Name | Should -Be 'Intune-AG-CompanyPortal-Available'
        }

        It 'Records one start and one end for a piped batch' {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
            $null = 'App1', 'App2', 'App3' | New-IntuneAppGroup -Confirm:$false
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' } -Times 1 -Exactly
        }

        It 'Records end telemetry when a downstream command stops the pipeline early' {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
            $result = 'App1', 'App2' | New-IntuneAppGroup -Confirm:$false | Select-Object -First 1
            $result.Name | Should -Be 'Intune-AG-App1-Available'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
        }
    }

    Context 'Existing groups and -WhatIf' {
        It 'Returns groups that already exist with Status Existing and a warning' {
            Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ Id = 'existing-id'; DisplayName = 'existing'; MailNickname = 'existing-nick' } } -ParameterFilter { $Filter -like '*-Available*' }
            $result = New-IntuneAppGroup -Name 'App1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
            @($result).Count | Should -Be 2
            $result[0].Status | Should -Be 'Existing'
            $result[0].Id | Should -Be 'existing-id'
            $result[0].MailNickname | Should -Be 'existing-nick'
            $result[1].Status | Should -Be 'Created'
            $warnings | Should -Match 'already exists'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly
        }

        It 'Looks groups up but creates nothing with -WhatIf' {
            $result = New-IntuneAppGroup -Name 'App1' -WhatIf
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
            Should -Invoke -ModuleName tcs.azure Get-EntraGroup -Times 2 -Exactly
            $result.Status | Should -Be @('WhatIf', 'WhatIf')
            @($result | Where-Object { $_.Id }).Count | Should -Be 0
        }

        It 'Reports existing groups as Existing under -WhatIf and only offers the others' {
            Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ Id = 'existing-id' } } -ParameterFilter { $Filter -like '*-Required*' }
            $result = New-IntuneAppGroup -Name 'App1' -WhatIf -WarningAction SilentlyContinue
            $result.Status | Should -Be @('WhatIf', 'Existing')
        }
    }

    Context 'Errors' {
        It 'Writes a non-terminating error and continues when a group cannot be created' {
            Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' } -ParameterFilter { $DisplayName -like '*-Available' }
            $result = New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
            ($errors | Out-String) | Should -Match 'Insufficient privileges'
            @($result).Count | Should -Be 2
            $result[0].Status | Should -Be 'Failed'
            $result[1].Name | Should -Be 'Intune-AG-App1-Required'
            $result[1].Status | Should -Be 'Created'
        }

        It 'Stops on the first failure with -ErrorAction Stop' {
            Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
            { New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorAction Stop } | Should -Throw '*Insufficient privileges*'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly
        }

        It 'Writes an error for a whitespace-only name' {
            $null = New-IntuneAppGroup -Name '   ' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
            @($errors).Count | Should -Be 1
            $errors[0].FullyQualifiedErrorId | Should -BeLike 'BlankName*'
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
        }

        It 'Throws one clear error when there is no Connect-Entra session' {
            Mock -ModuleName tcs.azure Get-EntraContext { }
            { New-IntuneAppGroup -Name 'App1', 'App2' -Confirm:$false } | Should -Throw '*Connect-Entra*'
            Should -Invoke -ModuleName tcs.azure Get-EntraGroup -Times 0 -Exactly
            Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
        }

        It 'Uses the EntraNotConnected error id when there is no session' {
            Mock -ModuleName tcs.azure Get-EntraContext { }
            try {
                New-IntuneAppGroup -Name 'App1' -Confirm:$false
            }
            catch {
                $caught = $_
            }
            $caught.FullyQualifiedErrorId | Should -BeLike 'EntraNotConnected*'
        }
    }

    Context 'Telemetry' {
        BeforeEach {
            Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        }

        It 'Records start and end telemetry' {
            $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
        }

        It 'Records failed end telemetry when a group cannot be created' {
            Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
            $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorAction SilentlyContinue
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
        }

        It 'Records failed end telemetry for a blank name' {
            $null = New-IntuneAppGroup -Name ' ' -Confirm:$false -ErrorAction SilentlyContinue
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 0 -Exactly
        }

        It 'Records failed end telemetry once with -ErrorAction Stop' {
            Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
            { New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorAction Stop } | Should -Throw
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' } -Times 1 -Exactly
            Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
        }
    }

    Context 'Parameters' {
        It 'Requires a name' {
            (Get-Command -Name New-IntuneAppGroup).Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
        }

        It 'Supports -WhatIf and -Confirm' {
            $command = Get-Command -Name New-IntuneAppGroup
            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }
}

Describe 'New-IntuneAppGroup without the Microsoft Entra module' {
    It 'Throws a helpful error when the Entra commands are missing' {
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -in 'Get-EntraGroup', 'New-EntraGroup' }
        { New-IntuneAppGroup -Name 'App1' -Confirm:$false } | Should -Throw '*Install-Module Microsoft.Entra.Groups*'
    }

    It 'Records failed end telemetry when the Entra commands are missing' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -in 'Get-EntraGroup', 'New-EntraGroup' }
        { New-IntuneAppGroup -Name 'App1' -Confirm:$false } | Should -Throw
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
    }

    It 'Skips the connection check when Get-EntraContext is not available' {
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -eq 'Get-EntraContext' }
        Mock -ModuleName tcs.azure Get-EntraGroup { }
        Mock -ModuleName tcs.azure New-EntraGroup { [pscustomobject]@{ Id = '1' } }
        $result = New-IntuneAppGroup -Name 'App1' -Intent Available -Confirm:$false
        $result.Status | Should -Be 'Created'
    }
}
