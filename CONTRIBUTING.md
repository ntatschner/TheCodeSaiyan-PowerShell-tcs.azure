# Contributing to tcs.azure

tcs.azure is part of the TheCodeSaiyan PowerShell suite and depends on
[tcs.core](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.core) 0.3.0 or later for
configuration, update checks and telemetry.

## Getting started

Requirements: PowerShell 7.2+ for development, tcs.core 0.3.0+, Pester 5.7.1 and
PSScriptAnalyzer 1.23.0. The Microsoft Entra module is **not** needed to run the tests; its
cmdlets are stubbed and mocked.

```powershell
Install-Module tcs.core -MinimumVersion 0.3.0 -Scope CurrentUser
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck
Install-Module PSScriptAnalyzer -RequiredVersion 1.23.0 -Scope CurrentUser

# Keep test runs offline and away from your real settings
$env:TCS_SKIP_UPDATE_CHECK = '1'
$env:TCS_TELEMETRY_OPTOUT = '1'

Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester -Path ./modules/tcs.azure, ./tests -Output Detailed

Invoke-ScriptAnalyzer -Path ./modules/tcs.azure -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error, Warning |
    Where-Object { $_.ScriptName -notlike '*.Tests.ps1' }
```

## Layout

| Path | Contents |
| --- | --- |
| `modules/tcs.azure/Public/` | Exported functions, one per file, named after the function |
| `modules/tcs.azure/Private/` | Internal helpers (not exported) |
| `modules/tcs.azure/Public/Tests/` | Pester tests, `<Function>.Tests.ps1` |
| `tests/` | Module-wide tests (manifest, exports, help, PSScriptAnalyzer) |
| `.github/scripts/` | Smoke tests run by the shared validation workflow |

Every file in `Public/` must also be listed in `FunctionsToExport` in `tcs.azure.psd1`;
`tests/Module.Tests.ps1` checks this.

## Standards

- **Compatibility:** code must run on Windows PowerShell 5.1 and PowerShell 7 on Windows,
  Linux and macOS. Avoid PS7-only syntax (`??`, `?:`, `&&`, `ForEach-Object -Parallel`,
  `ValidateScript(ErrorMessage = ...)`) and .NET Core-only APIs. CI runs the tests on all four.
- **Style:** 4-space indentation, `CmdletBinding()` on every function, approved verbs,
  full command names (no aliases). PSScriptAnalyzer runs with `PSScriptAnalyzerSettings.psd1`
  and **warnings fail the build**. Suppress a rule only with a written justification.
- **State-changing functions** (`New-`, `Set-`, `Remove-` ...) support `-WhatIf`/`-Confirm`.
- **Help:** every exported function has comment-based help with a synopsis, description,
  every parameter and at least one example.
- **Tests:** new behaviour and bug fixes come with Pester tests. Tests must not touch the real
  user profile, the network or a real tenant: set `TCS_CONFIG_ROOT` to `$TestDrive` and mock
  the Microsoft Entra cmdlets.
- **Versioning:** [Semantic Versioning](https://semver.org). Record changes in `CHANGELOG.md`.

## Releasing

1. Update `ModuleVersion` in `modules/tcs.azure/tcs.azure.psd1`.
2. Update `CHANGELOG.md`, open a pull request and merge it to `main`.
