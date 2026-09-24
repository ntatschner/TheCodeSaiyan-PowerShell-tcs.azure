# tcs.azure PowerShell Module

*Helper functions for Microsoft Azure and Microsoft Entra ID*

- `Get-DepartmentalGroupName` builds a standard departmental group name (alias
  `New-TcsDepartmentalGroup`, its name before 0.2.0).
- `New-TcsEntraDepartmentalGroup` creates that group in Entra ID, optionally with dynamic
  membership and owners.
- `New-IntuneAppGroup` creates Intune app assignment groups (Available, Required, Uninstall) in
  Entra ID; `Get-IntuneAppGroup` finds them and `Remove-IntuneAppGroup` deletes them.

The Entra commands need the Microsoft Entra PowerShell module and `Connect-Entra`; the commands
that change Entra ID support `-WhatIf`.

Requires tcs.core 0.3.0 or later. See the
[repository README](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure) for
installation, configuration and the telemetry statement.
