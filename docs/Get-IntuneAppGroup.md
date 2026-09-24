---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version:
schema: 2.0.0
---

# Get-IntuneAppGroup

## SYNOPSIS
Gets Intune app assignment groups from Microsoft Entra ID.

## SYNTAX

### ByName (Default)
```
Get-IntuneAppGroup [-Name] <String[]> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### All
```
Get-IntuneAppGroup [-All] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-IntuneAppGroup function finds the groups created by New-IntuneAppGroup.
With -Name it
returns the app groups and app collection groups of those applications
('Intune-AG-\<Name\>-\<Intent\>' and 'Intune-ACG-\<Name\>-\<Intent\>'); the name is converted to
PascalCase the same way as in New-IntuneAppGroup.
With -All it returns every group whose name
starts with 'Intune-AG-' or 'Intune-ACG-'.

Groups are found with a startswith filter on the display name (all result pages).
Each group is
returned as a Tcs.Azure.IntuneAppGroup object with Name, Id, AppName, Intent, Status ('Existing')
and MailNickname, so it can be piped to Remove-IntuneAppGroup.
AppName and Intent are read from
the group name and are empty for a group that does not follow the naming pattern.

Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
session opened with Connect-Entra that can read groups, for example the Group.Read.All scope.

## EXAMPLES

### EXAMPLE 1
```
Get-IntuneAppGroup -Name 'Company Portal'
```

Returns Intune-AG-CompanyPortal-Available, Intune-AG-CompanyPortal-Required and any other groups
for Company Portal that exist.

### EXAMPLE 2
```
Get-IntuneAppGroup -All | Group-Object -Property AppName
```

Lists every Intune app group, grouped by application.

## PARAMETERS

### -Name
One or more application names.
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

### -All
Return every group whose name starts with 'Intune-AG-' or 'Intune-ACG-'.

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: True
Position: Named
Default value: False
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
## OUTPUTS

### Tcs.Azure.IntuneAppGroup
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[New-IntuneAppGroup]()

[Remove-IntuneAppGroup]()

[https://learn.microsoft.com/powershell/module/microsoft.entra.groups/get-entragroup](https://learn.microsoft.com/powershell/module/microsoft.entra.groups/get-entragroup)

