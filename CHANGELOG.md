# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-24

Requires tcs.core 0.3.0 or later.

### Breaking
- Requires `tcs.core` 0.3.0 or later (`RequiredModules` now pins the minimum version).
- `New-IntuneAppGroup`: `-Name` is now mandatory, and the command now supports `-WhatIf`/`-Confirm`
  (`ConfirmImpact` is Medium, so no prompt by default).
- `New-TcsDepartmentalGroup`: `-Prefix` and `-Suffix` are now really validated to contain no whitespace.
- Removed the unused module-scoped colour variables (`Colors.ps1`) and the unused `Config.ps1`.

### Added
- Pester tests for both functions (Entra cmdlets mocked) and module-wide tests (manifest,
  exports, help, PSScriptAnalyzer, clean import).
- CI: Pester matrix on Windows PowerShell 5.1 and PowerShell 7 (Windows, Ubuntu, macOS) with
  pinned Pester 5.7.1 / PSScriptAnalyzer 1.23.0; lint fails on warnings; smoke tests.
- `New-IntuneAppGroup` records start/end usage telemetry through tcs.core and gives a clear error
  with install instructions when the Microsoft Entra module is missing.
- Comment-based help for `New-TcsDepartmentalGroup`.
- README, CONTRIBUTING, SECURITY, editor/git settings, CODEOWNERS, Dependabot, issue and PR templates.

### Fixed
- `New-TcsDepartmentalGroup` was never exported: its file defined `New-DepartmentalGroup`.
- `New-TcsDepartmentalGroup`: `[CmdletBinding()]` was inside `param()`; `ValidateScript(ErrorMessage = ...)`
  does not exist in Windows PowerShell 5.1 and its `'^\s$'` check never rejected names with spaces;
  repeated or trailing spaces in the division caused a `Substring` exception.
- `New-IntuneAppGroup`: repeated spaces in a name caused a `Substring` exception; single quotes in a
  name broke the OData filter; characters Entra ID rejects in a mail nickname (for example
  parentheses) made group creation fail; lookup errors were not caught reliably (`-ErrorAction Stop`).
- Manifest used `NestedModules` without a `RootModule`; it now uses `RootModule = 'tcs.azure.psm1'`.
  `ExternalModuleDependencies` named a non-existent module (`Microsoft.Graph.Entra`); it is now
  `Microsoft.Entra.Groups`.
- Module import uses the tcs.core 0.3.0 telemetry and cached update check, never fails because of
  them, writes nothing to the pipeline, and uses `Join-Path` so it loads on Linux and macOS.

### Changed
- PSScriptAnalyzer settings aligned with tcs.core.

## Earlier unreleased changes (shipped in 0.1.0)

### Added
- PSScriptAnalyzer settings file for consistent linting
- GitHub Actions CI workflow with lint, Pester, and module validation jobs
- Classes/ directory loading in psm1 (before function dot-sourcing)
- `-Recurse` flag on Public/Private function discovery

### Fixed
- Consistent UpdateWarning boolean comparison (`-eq $true` pattern)
