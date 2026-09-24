# tcs.azure PowerShell Module

*Helper functions for Microsoft Azure and Microsoft Entra ID*

- `New-TcsDepartmentalGroup` builds a standard departmental group name.
- `New-IntuneAppGroup` creates Intune "Available"/"Required" app assignment groups in Entra ID
  (needs the Microsoft Entra PowerShell module and `Connect-Entra`; supports `-WhatIf`).

Requires tcs.core 0.3.0 or later. See the
[repository README](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.azure) for
installation, configuration and the telemetry statement.
