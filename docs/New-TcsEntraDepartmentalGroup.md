---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version:
schema: 2.0.0
---

# New-TcsEntraDepartmentalGroup

## SYNOPSIS
Creates a departmental security group in Microsoft Entra ID.

## SYNTAX

```
New-TcsEntraDepartmentalGroup [-Prefix] <String> [[-Suffix] <String>] [-Division] <String>
 [[-Department] <String>] [-DynamicMembership] [[-Owner] <String[]>] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The New-TcsEntraDepartmentalGroup function builds a group name with the same rules as
Get-DepartmentalGroupName (see Get-Help Get-DepartmentalGroupName) and creates a security group
with that name in Microsoft Entra ID.

The group is looked up first.
An existing group (same display name) is not created again: a
warning is written and it is returned with Status 'Existing'.
Only groups that do not exist yet
are passed to -WhatIf/-Confirm and created.

With -DynamicMembership the group gets the membership rule
(user.department -eq "\<Department\>"), using the department as written (or the division when no
department is given), and membershipRuleProcessingState On, so Entra ID keeps the members up to
date.
Dynamic membership groups need a Microsoft Entra ID P1 licence.
The Microsoft.Entra.Groups
New-EntraGroup (1.x) has no -MembershipRule parameter; in that case New-EntraBetaGroup from
Microsoft.Entra.Beta.Groups is used, and the command stops with an error when neither supports it.

With -Owner the given users or service principals are added as owners (Add-EntraGroupOwner).

For every group an object is written to the pipeline with the properties Name, Id, Status
(Created, Existing, Failed or WhatIf), MembershipRule and MailNickname.

Requires the Microsoft Entra PowerShell module (Microsoft.Entra or Microsoft.Entra.Groups) and a
session opened with Connect-Entra that can create groups, for example the Group.ReadWrite.All scope.
Supports -WhatIf and -Confirm.

## EXAMPLES

### EXAMPLE 1
```
New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'Payroll' -WhatIf
```

Shows that the security group SG-HR-Payroll would be created.

### EXAMPLE 2
```
New-TcsEntraDepartmentalGroup -Prefix 'SG' -Division 'Finance' -Department 'Accounts Payable' -DynamicMembership -Owner $ownerId
```

Creates SG-F-AccountsPayable with the rule (user.department -eq "Accounts Payable") and adds an owner.

### EXAMPLE 3
```
Import-Csv .\departments.csv | New-TcsEntraDepartmentalGroup -Prefix 'SG' -Suffix 'Users'
```

Creates one group for each row; the CSV has Division and Department columns.

## PARAMETERS

### -Prefix
The first part of the group name, for example 'SG'.
Cannot contain whitespace.
Accepts pipeline input by property name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Suffix
An optional last part of the group name, for example 'Users'.
Cannot contain whitespace.
Accepts pipeline input by property name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Division
The division the group belongs to, for example 'Human Resources'.
Accepts pipeline input by
property name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Department
The optional department within the division, for example 'Payroll'.
Accepts pipeline input by
property name.
With -DynamicMembership this is the value matched against user.department.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DynamicMembership
Create a dynamic membership group with the rule (user.department -eq "\<Department\>"), or the
division when no department is given.

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

### -Owner
Object IDs of users or service principals to add as owners of a created group.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
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

### System.Management.Automation.PSObject
### Objects with Prefix, Suffix, Division and Department properties (for example rows from Import-Csv).
## OUTPUTS

### Tcs.Azure.DepartmentalGroup
### One object for each group, with Name, Id, Status, MembershipRule and MailNickname.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Get-DepartmentalGroupName]()

[https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership](https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership)

