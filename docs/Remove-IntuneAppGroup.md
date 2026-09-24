---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version:
schema: 2.0.0
---

# Remove-IntuneAppGroup

## SYNOPSIS
Deletes Intune app assignment groups from Microsoft Entra ID.

## SYNTAX

### ByName (Default)
```
Remove-IntuneAppGroup [-Name] <String[]> [-Intent <String[]>] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### ById
```
Remove-IntuneAppGroup -Id <String[]> [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The Remove-IntuneAppGroup function deletes the groups created by New-IntuneAppGroup.

With -Name, the app groups and app collection groups of those applications are found the same
way as Get-IntuneAppGroup -Name does; use -Intent to delete only some of them.
With -Id (or by
piping the output of Get-IntuneAppGroup or New-IntuneAppGroup), the groups with those object IDs
are deleted.
A group whose name does not start with 'Intune-AG-' or 'Intune-ACG-' is never
deleted; an error is written instead.

Deleted security groups cannot be restored.
ConfirmImpact is High, so you are asked to confirm
each group unless you use -Confirm:$false.
Supports -WhatIf.
Nothing is written to the pipeline.

Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
session opened with Connect-Entra that can delete groups, for example the Group.ReadWrite.All scope.

## EXAMPLES

### EXAMPLE 1
```
Remove-IntuneAppGroup -Name 'Company Portal' -WhatIf
```

Shows which Company Portal groups would be deleted.

### EXAMPLE 2
```
Remove-IntuneAppGroup -Name 'Company Portal' -Intent Uninstall -Confirm:$false
```

Deletes Intune-AG-CompanyPortal-Uninstall (and Intune-ACG-CompanyPortal-Uninstall) without asking.

### EXAMPLE 3
```
Get-IntuneAppGroup -All | Where-Object AppName -EQ 'OldApp' | Remove-IntuneAppGroup
```

Deletes the groups returned by Get-IntuneAppGroup, asking for each one.

## PARAMETERS

### -Name
One or more application names whose groups are deleted.
Accepts pipeline input.

```yaml
Type: String[]
Parameter Sets: ByName
Aliases: AppName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Intent
With -Name, delete only the groups for these intents (Available, Required, Uninstall).
By
default the groups for every intent are deleted.

```yaml
Type: String[]
Parameter Sets: ByName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Id
The object IDs of the groups to delete.
Accepts pipeline input by property name (Id, ObjectId or
GroupId), for example from Get-IntuneAppGroup.

```yaml
Type: String[]
Parameter Sets: ById
Aliases: ObjectId, GroupId

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
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
### Objects with an Id property, such as the output of Get-IntuneAppGroup.
## OUTPUTS

### None
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Get-IntuneAppGroup]()

[New-IntuneAppGroup]()

[https://learn.microsoft.com/powershell/module/microsoft.entra.groups/remove-entragroup](https://learn.microsoft.com/powershell/module/microsoft.entra.groups/remove-entragroup)

