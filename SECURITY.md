# Security Policy

## Supported versions

Only the latest released version of tcs.azure receives security fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report them privately through
[GitHub security advisories](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure/security/advisories/new).
Include the affected version, the steps to reproduce and the impact you expect.

You should get a first response within 7 days.

## Scope notes

- tcs.azure does not store credentials. `New-IntuneAppGroup` uses the Microsoft Entra
  PowerShell session you open with `Connect-Entra`.
- Telemetry (collected through tcs.core) never sends user names, machine names, paths,
  hardware identifiers, command arguments such as group names, or error messages. Report
  anything that suggests otherwise as a security issue.
