# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-24

Requires tcs.core 0.3.0 or later.

### Breaking
- `New-TcsDepartmentalGroup` is renamed to `Get-DepartmentalGroupName` (it only returns a name).
  `New-TcsDepartmentalGroup` still works as an alias, but telemetry and errors use the new name.
- Departmental names changed for some input: all-caps words are kept (`IT` gives `SG-IT`, was
  `SG-It`), the rest of a word is no longer lower-cased (`FINANCE` stays `FINANCE`), stop words
  (and, of, the, &) are skipped in initials (`Sales & Marketing` gives `SM`, was `SAM`),
  acronyms (all-caps words of 2-4 characters) are kept whole in initials (`IT Services` gives `ITS`), characters such as `( ) / \ .`
  are removed and stand-alone hyphens now separate parts (`Accounts Payable - UK` gives
  `AccountsPayable-UK`, was `AccountsPayable-Uk`).
- `New-IntuneAppGroup` now returns a `Tcs.Azure.IntuneAppGroup` object for every group (Name, Id,
  AppName, Intent, Status, MailNickname; `DisplayName` is an alias of Name) instead of the raw
  `New-EntraGroup` output, including existing groups (Status `Existing`), failed groups (`Failed`)
  and, under `-WhatIf`, groups that would be created (`WhatIf`).
- `New-IntuneAppGroup` looks each group up before `-WhatIf`/`-Confirm`, so `-WhatIf` now needs a
  connected session, and only groups that do not exist yet are offered for confirmation.
- `New-IntuneAppGroup` descriptions now read `Intune <Intent> assignment group for <App>.`
- The Entra commands stop with one "run Connect-Entra" error when `Get-EntraContext` shows no session.

### Added
- `New-TcsEntraDepartmentalGroup`: creates the departmental security group in Entra ID, skipping
  (and returning) an existing one, with `-WhatIf`, optional `-DynamicMembership`
  (`(user.department -eq "<Department>")`, processing state On) and `-Owner`.
- `Get-IntuneAppGroup` (`-Name` or `-All`) and `Remove-IntuneAppGroup` (by `-Name`/`-Intent` or
  `-Id`, `ConfirmImpact` High, `-WhatIf`; refuses groups without the Intune app group prefix).
- `New-IntuneAppGroup -Intent` (Available, Required, Uninstall; default Available and Required).
- Pipeline input: `New-IntuneAppGroup -Name` (by value and by property name Name, AppName or
  DisplayName); `Get-DepartmentalGroupName` Prefix, Suffix, Division and Department by property name.
- The departmental naming rules are documented in `Get-Help Get-DepartmentalGroupName`.
- Tests for long and non-ASCII names, tr-TR culture, punctuation-only divisions, early pipeline
  stop, blank-name telemetry, intents, pipeline input and the new commands.

### Fixed
- `New-IntuneAppGroup`: mail nicknames longer than Entra ID's 64-character limit are shortened
  with a stable hash, so creation no longer fails for long application names.
- `New-IntuneAppGroup`: non-ASCII names no longer all get the same nickname (`Intune-AG--Available`);
  accents are removed and names with no usable characters get a stable hash.
- `New-IntuneAppGroup`: a blank application name was reported to telemetry as a success.
- `Get-DepartmentalGroupName`: a division of `,` gave a raw parameter validation error and `&`
  gave `SG-And`; both now give a clear `InvalidDivision` error.
- `Get-DepartmentalGroupName`: `HR -` gave `SG-Hr-`; `HR` with department `HR` repeated the part.
- Culture-sensitive casing: under tr-TR, `i` became a dotted capital I in group names.
- End telemetry was not sent when a downstream command (for example `Select-Object -First 1`)
  stopped the pipeline.

### Changed
- One private PascalCase helper is used by all commands (acronyms, mixed case and hyphenated
  names such as `7-zip` are kept the same way everywhere).
- Removed the PSScriptAnalyzer suppression that only existed for the `New` verb.

## [0.1.1] - 2026-09-24

### Fixed
- Restored the hand-written `about_tcs.azure` help topic. The shared docs workflow had replaced it with the PlatyPS placeholder.
- Reworded a changelog entry that used a name from another organisation.

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
- `New-TcsDepartmentalGroup` records start/end usage telemetry through tcs.core (every exported
  command now does); a module test fails if an exported command does not send Start and End telemetry.
- `about_tcs.azure` help topic (`Get-Help about_tcs.azure`).
- Release workflows calling the shared tcs workflows: `create-version-tag.yml` (tags `v<ModuleVersion>`
  when the manifest version increases), `generate-docs.yml` (PlatyPS markdown and external help in
  `docs/`) and `publish-to-psgallery.yml`; `.github/PUBLISHING.md` describes the release steps.

### Fixed
- `New-TcsDepartmentalGroup` was never exported: its file defined the function under a different name.
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
- CI workflow renamed to `CI Validate` so the tag and docs workflows can run after it.

## Earlier unreleased changes (shipped in 0.1.0)

### Added
- PSScriptAnalyzer settings file for consistent linting
- GitHub Actions CI workflow with lint, Pester, and module validation jobs
- Classes/ directory loading in psm1 (before function dot-sourcing)
- `-Recurse` flag on Public/Private function discovery

### Fixed
- Consistent UpdateWarning boolean comparison (`-eq $true` pattern)
