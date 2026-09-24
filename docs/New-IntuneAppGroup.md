---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version:
schema: 2.0.0
---

# New-IntuneAppGroup

## SYNOPSIS
Creates Intune app assignment groups (for example "Available" and "Required") in Microsoft Entra ID.

## SYNTAX

```
New-IntuneAppGroup [-Name] <String[]> [-Intent <String[]>] [-Collection] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The New-IntuneAppGroup function creates one security group in Microsoft Entra ID for each
application name and each assignment intent.
By default the "Available" and "Required" groups are
created; use -Intent to choose (Available, Required, Uninstall).

Groups are named 'Intune-AG-\<Name\>-\<Intent\>' (app groups) or 'Intune-ACG-\<Name\>-\<Intent\>' (app
collection groups, with -Collection).
The name is written in PascalCase with spaces removed: the
first letter of each word is upper-cased (culture-independent) and the rest is kept, for example
'company portal' becomes 'CompanyPortal' and '7-zip' stays '7-zip'.
The description is
'Intune \<Intent\> assignment group for \<Name\>.'

The mail nickname is the group name made valid for Entra ID: accents are removed (an A with an umlaut becomes A),
characters Entra ID does not allow are removed, a name with no usable characters left gets a
short stable hash instead, and a nickname longer than 64 characters is shortened with a hash of
the full group name added, so different applications keep different nicknames.

Each group is looked up first.
An existing group (same display name) is not created again: a
warning is written and it is returned with Status 'Existing'.
Only groups that do not exist yet
are passed to -WhatIf/-Confirm and created.

For every group an object is written to the pipeline with the properties Name, Id, AppName,
Intent, Status (Created, Existing, Failed or WhatIf) and MailNickname.
DisplayName is an alias of Name.

Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and an
authenticated session (Connect-Entra) with permission to create groups, for example the
Group.ReadWrite.All scope.
When Get-EntraContext shows no session, the command stops with one
error asking you to run Connect-Entra.
Supports -WhatIf and -Confirm.

## EXAMPLES

### EXAMPLE 1
```
New-IntuneAppGroup -Name 'App1', 'App2'
```

Creates Intune-AG-App1-Available, Intune-AG-App1-Required, Intune-AG-App2-Available and
Intune-AG-App2-Required, and returns an object for each of them.

### EXAMPLE 2
```
New-IntuneAppGroup -Collection -Name 'office apps' -WhatIf
```

Shows that Intune-ACG-OfficeApps-Available and Intune-ACG-OfficeApps-Required would be created,
without creating them.
Groups that already exist are returned with Status 'Existing'.

### EXAMPLE 3
```
'Company Portal', '7-Zip' | New-IntuneAppGroup -Intent Required, Uninstall
```

Creates the Required and Uninstall groups for both applications.

### EXAMPLE 4
```
New-IntuneAppGroup -Name 'Company Portal' | Where-Object Status -EQ 'Created'
```

Returns only the groups that were created by this run.

## PARAMETERS

### -Name
One or more application names.
One group is created for each name and intent.
Accepts pipeline
input, and pipeline input by property name (Name, AppName or DisplayName).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: AppName, DisplayName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Intent
The assignment intents to create groups for: Available, Required and/or Uninstall.
The default is
Available and Required.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @('Available', 'Required')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Collection
Create app collection groups ('Intune-ACG-...') instead of app groups ('Intune-AG-...').

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### Application names.
### System.Management.Automation.PSObject
### Objects with a Name, AppName or DisplayName property.
## OUTPUTS

### Tcs.Azure.IntuneAppGroup
### One object for each group, with Name, Id, AppName, Intent, Status and MailNickname.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Get-IntuneAppGroup]()

[Remove-IntuneAppGroup]()

[https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup](https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup)

