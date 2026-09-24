---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version: https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup
schema: 2.0.0
---

# New-IntuneAppGroup

## SYNOPSIS
Creates Intune app assignment groups ("Available" and "Required") in Microsoft Entra ID.

## SYNTAX

```
New-IntuneAppGroup [-Name] <String[]> [-Collection] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The New-IntuneAppGroup function creates two security groups in Microsoft Entra ID for each
application name: one for "Available" and one for "Required" Intune assignments.

Groups are named 'Intune-AG-\<Name\>-\<Intent\>' (app groups) or 'Intune-ACG-\<Name\>-\<Intent\>' (app
collection groups, with -Collection).
The name is converted to PascalCase with spaces removed,
for example 'company portal' becomes 'CompanyPortal'.
The mail nickname is the group name with
characters that Entra ID does not allow in a mail nickname removed.

A group that already exists (same display name) is skipped with a warning.
The created group objects
are written to the pipeline.

Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and an
authenticated session (Connect-Entra) with permission to create groups, for example the
Group.ReadWrite.All scope.
Supports -WhatIf and -Confirm.

## EXAMPLES

### EXAMPLE 1
```
New-IntuneAppGroup -Name 'App1', 'App2'
```

Creates Intune-AG-App1-Available, Intune-AG-App1-Required, Intune-AG-App2-Available and
Intune-AG-App2-Required.

### EXAMPLE 2
```
New-IntuneAppGroup -Collection -Name 'office apps' -WhatIf
```

Shows that Intune-ACG-OfficeApps-Available and Intune-ACG-OfficeApps-Required would be created,
without creating them.

## PARAMETERS

### -Name
One or more application names.
Two groups ("Available" and "Required") are created for each name.

```yaml
Type: String[]
Parameter Sets:   (All)
Aliases:
Required: True
Position: 1Default
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -Collection
Create app collection groups ('Intune-ACG-...') instead of app groups ('Intune-AG-...').

```yaml
Type:Switch
Parameter Sets:   (All)
Aliases:
Required: False
Position:Named
Default value: None
Default value: None
Default value: False
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type:Switch
Parameter Sets:   (All)
Aliases:wi
Required: False
Position:Named
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type:Switch
Parameter Sets:   (All)
Aliases:cf
Required: False
Position:Named
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type:ActionPreference
Parameter Sets:   (All)
Aliases:proga
Required: False
Position:Named
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
### This function does not accept pipeline input.
## OUTPUTS

### System.Object
### The group objects returned by New-EntraGroup.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup](https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup)

