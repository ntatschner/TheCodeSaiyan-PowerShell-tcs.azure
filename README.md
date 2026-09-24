# TheCodeSaiyan PowerShell tcs.azure Module

[![Build Status](https://img.shields.io/github/actions/workflow/status/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure/ci-validate.yml?branch=main&style=flat-square&label=Build)](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure/actions/workflows/ci-validate.yml)

Helper functions for Microsoft Azure and Microsoft Entra ID: consistent departmental group
names and Intune app assignment groups. Part of the TheCodeSaiyan PowerShell suite, built on
[tcs.core](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.core).

## Requirements

- Windows PowerShell 5.1 or PowerShell 7 on Windows, Linux or macOS
- [tcs.core](https://www.powershellgallery.com/packages/tcs.core) **0.3.0 or later** (declared in
  `RequiredModules`; install it first when importing from source)
- For `New-IntuneAppGroup` only: the Microsoft Entra PowerShell module
  (`Microsoft.Entra.Groups` or the full `Microsoft.Entra`) and a session opened with
  `Connect-Entra` that is allowed to create groups (for example `Group.ReadWrite.All`).
  It is not installed automatically; the command tells you if it is missing.

## Installation

### From GitHub source

```powershell
Install-Module -Name tcs.core -MinimumVersion 0.3.0 -Scope CurrentUser
git clone https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure.git
Import-Module ./TheCodeSaiyan-PowerShell-tcs.azure/modules/tcs.azure/tcs.azure.psd1

# Only needed for New-IntuneAppGroup
Install-Module -Name Microsoft.Entra.Groups -Scope CurrentUser
```

## Functions

| Function | Purpose |
| --- | --- |
| `New-TcsDepartmentalGroup` | Builds a standard group name such as `SG-HR-Payroll-Users` from a prefix, division, department and suffix. Returns a string; creates nothing. |
| `New-IntuneAppGroup` | Creates `Intune-AG-<App>-Available` / `-Required` (or `Intune-ACG-...` with `-Collection`) security groups in Entra ID. Skips groups that already exist. Supports `-WhatIf` and `-Confirm`. |

### Examples

```powershell
New-TcsDepartmentalGroup -Prefix SG -Division 'Human Resources'
# SG-HumanResources

New-TcsDepartmentalGroup -Prefix SG -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix Users
# SG-HR-PayrollAndBenefits-Users

Connect-Entra -Scopes Group.ReadWrite.All
New-IntuneAppGroup -Name 'Company Portal', '7-Zip' -WhatIf     # preview
New-IntuneAppGroup -Name 'Company Portal', '7-Zip'             # create four groups
New-IntuneAppGroup -Name 'Office Apps' -Collection             # Intune-ACG-OfficeApps-*
```

Run `Get-Help <function> -Full` for all parameters.

## Configuration

Settings are managed by tcs.core and stored per user at
`<ApplicationData>/PowerShell/Config/tcs.azure/Module.Config.json` (`%APPDATA%` on Windows,
`~/.config` on Linux/macOS). Nothing is written into the module folder. Change them with
`Set-ModuleConfig`:

```powershell
Set-ModuleConfig -ModuleName tcs.azure -UpdateWarning $false   # no update warnings on import
Set-ModuleConfig -ModuleName tcs.azure -Telemetry $false       # no telemetry for tcs.azure
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `UpdateWarning` | `true` | Warn on import when a newer version is in the PowerShell Gallery (checked at most once a day) |
| `UpdateCheckIntervalHours` | `24` | How often the gallery is checked |
| `Telemetry` | `true` | Send anonymous usage telemetry |

The environment variables `TCS_TELEMETRY_OPTOUT=1`, `TCS_SKIP_UPDATE_CHECK=1` and
`TCS_CONFIG_ROOT` work as described in the tcs.core README.

## Privacy and telemetry

tcs modules send anonymous usage telemetry to help find failing commands. Telemetry is on by
default and a notice is shown the first time a module is loaded. Nothing is sent until a
telemetry endpoint is configured.

Each event contains: time (UTC), module and command name, module version, duration, success,
the exception **type** on failure, PowerShell version and edition, OS family, PowerShell host
name, and a random installation ID created on first use.

It **never** contains: user names, machine names, file paths, hardware serial numbers, IP-based
identifiers, command arguments (such as group or application names), tenant details or error
messages.

Turn it off with `Set-ModuleConfig -ModuleName tcs.azure -Telemetry $false`, or for all tcs
modules with the environment variable `TCS_TELEMETRY_OPTOUT=1`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and PSScriptAnalyzer, and the
coding standards. Report security issues as described in [SECURITY.md](SECURITY.md).
Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Author

**Nigel Tatschner** - TheCodeSaiyan
- GitHub: [@ntatschner](https://github.com/ntatschner)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
