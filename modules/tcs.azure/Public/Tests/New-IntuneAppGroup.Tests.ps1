BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.azure.psd1') -Force

    # Pester can only mock commands that exist. When the Microsoft Entra module is not installed,
    # define stand-ins with the parameters New-IntuneAppGroup uses.
    $script:CreatedStubs = @()
    if (-not (Get-Command -Name Get-EntraGroup -ErrorAction SilentlyContinue)) {
        function global:Get-EntraGroup {
            [CmdletBinding()]
            param([string]$Filter)
            $null = $PSBoundParameters
        }
        $script:CreatedStubs += 'Get-EntraGroup'
    }
    if (-not (Get-Command -Name New-EntraGroup -ErrorAction SilentlyContinue)) {
        function global:New-EntraGroup {
            [CmdletBinding()]
            param([string]$DisplayName, [string]$MailNickname, [string]$Description, [bool]$MailEnabled, [bool]$SecurityEnabled)
            $null = $PSBoundParameters
        }
        $script:CreatedStubs += 'New-EntraGroup'
    }
}

AfterAll {
    foreach ($stub in $script:CreatedStubs) {
        Remove-Item -Path "Function:\$stub" -ErrorAction SilentlyContinue
    }
    Remove-Module -Name tcs.azure -Force -ErrorAction SilentlyContinue
}

Describe 'New-IntuneAppGroup' {
    BeforeEach {
        Mock -ModuleName tcs.azure Get-EntraGroup { }
        Mock -ModuleName tcs.azure New-EntraGroup { [pscustomobject]@{ DisplayName = $DisplayName; MailNickname = $MailNickname } }
    }

    It 'Creates an Available and a Required app group for each name' {
        $result = New-IntuneAppGroup -Name 'App1', 'App2' -Confirm:$false
        $result.DisplayName | Should -Be @('Intune-AG-App1-Available', 'Intune-AG-App1-Required', 'Intune-AG-App2-Available', 'Intune-AG-App2-Required')
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 4 -Exactly
    }

    It 'Creates security groups that are not mail enabled, with a description' {
        $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly -ParameterFilter {
            $DisplayName -eq 'Intune-AG-App1-Required' -and $SecurityEnabled -eq $true -and $MailEnabled -eq $false -and
            $Description -eq 'Intune App Group for "App1", this is an Required install.'
        }
    }

    It 'Uses the ACG prefix with -Collection' {
        $result = New-IntuneAppGroup -Name 'Office Apps' -Collection -Confirm:$false
        $result.DisplayName | Should -Be @('Intune-ACG-OfficeApps-Available', 'Intune-ACG-OfficeApps-Required')
    }

    It 'Converts names to PascalCase and tolerates repeated spaces' {
        $result = New-IntuneAppGroup -Name 'company   portal ' -Confirm:$false
        $result[0].DisplayName | Should -BeExactly 'Intune-AG-CompanyPortal-Available'
    }

    It 'Removes characters that are not valid in a mail nickname' {
        $result = New-IntuneAppGroup -Name 'App(x64)' -Confirm:$false
        $result[0].DisplayName | Should -BeExactly 'Intune-AG-App(x64)-Available'
        $result[0].MailNickname | Should -BeExactly 'Intune-AG-Appx64-Available'
    }

    It 'Escapes single quotes in the OData filter' {
        $null = New-IntuneAppGroup -Name "O'Brien" -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -ParameterFilter { $Filter -eq "DisplayName eq 'Intune-AG-O''Brien-Available'" } -Times 1 -Exactly
    }

    It 'Skips groups that already exist with a warning' {
        Mock -ModuleName tcs.azure Get-EntraGroup { [pscustomobject]@{ DisplayName = 'existing' } } -ParameterFilter { $Filter -like '*-Available*' }
        $result = New-IntuneAppGroup -Name 'App1' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
        @($result).Count | Should -Be 1
        $warnings | Should -Match 'already exists'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly
    }

    It 'Creates nothing with -WhatIf' {
        $null = New-IntuneAppGroup -Name 'App1' -WhatIf
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
        Should -Invoke -ModuleName tcs.azure Get-EntraGroup -Times 0 -Exactly
    }

    It 'Writes a non-terminating error and continues when a group cannot be created' {
        Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' } -ParameterFilter { $DisplayName -like '*-Available' }
        $result = New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        ($errors | Out-String) | Should -Match 'Insufficient privileges'
        @($result).Count | Should -Be 1
        $result.DisplayName | Should -Be 'Intune-AG-App1-Required'
    }

    It 'Stops on the first failure with -ErrorAction Stop' {
        Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
        { New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorAction Stop } | Should -Throw '*Insufficient privileges*'
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 1 -Exactly
    }

    It 'Writes an error for a whitespace-only name' {
        $null = New-IntuneAppGroup -Name '   ' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue
        @($errors).Count | Should -Be 1
        Should -Invoke -ModuleName tcs.azure New-EntraGroup -Times 0 -Exactly
    }

    It 'Records start and end telemetry' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'Start' } -Times 1 -Exactly
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and -not $Failed } -Times 1 -Exactly
    }

    It 'Records failed end telemetry when a group cannot be created' {
        Mock -ModuleName tcs.azure Invoke-TelemetryCollection { }
        Mock -ModuleName tcs.azure New-EntraGroup { throw 'Insufficient privileges' }
        $null = New-IntuneAppGroup -Name 'App1' -Confirm:$false -ErrorAction SilentlyContinue
        Should -Invoke -ModuleName tcs.azure Invoke-TelemetryCollection -ParameterFilter { $Stage -eq 'End' -and $Failed } -Times 1 -Exactly
    }

    It 'Requires a name' {
        (Get-Command -Name New-IntuneAppGroup).Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
    }

    It 'Supports -WhatIf and -Confirm' {
        $command = Get-Command -Name New-IntuneAppGroup
        $command.Parameters.Keys | Should -Contain 'WhatIf'
        $command.Parameters.Keys | Should -Contain 'Confirm'
    }
}

Describe 'New-IntuneAppGroup without the Microsoft Entra module' {
    It 'Throws a helpful error when the Entra commands are missing' {
        Mock -ModuleName tcs.azure Get-Command { } -ParameterFilter { $Name -in 'Get-EntraGroup', 'New-EntraGroup' }
        { New-IntuneAppGroup -Name 'App1' -Confirm:$false } | Should -Throw '*Install-Module Microsoft.Entra.Groups*'
    }
}
