---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version: https://learn.microsoft.com/powershell/module/microsoft.entra.groups/new-entragroup
schema: 2.0.0
---

# New-TcsDepartmentalGroup

## SYNOPSIS
Builds a standardised departmental group name.

## SYNTAX

```
New-TcsDepartmentalGroup [-Prefix] <String> [[-Suffix] <String>] [-Division] <String> [[-Department] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The New-TcsDepartmentalGroup function builds a group name from a prefix, a division, an optional
department and an optional suffix, separated by hyphens.
It only returns the name; it does not
create anything in Microsoft Entra ID or Azure.

Normalisation rules:
  - '&' is replaced with 'and' in the division and the department; commas are removed from the division.
  - Without a department, the division is written in PascalCase with spaces removed
    ('Human Resources' -\> 'HumanResources').
  - With a department, the division is abbreviated to the upper-case initials of its words
    ('Human Resources' -\> 'HR') and the department is written in PascalCase.
A leading
    '\<initials\> -' in the department ('HR - Payroll') is removed, so the initials are not repeated.

## EXAMPLES

### EXAMPLE 1
```
New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources'
```

Returns 'SG-HumanResources'.

### EXAMPLE 2
```
New-TcsDepartmentalGroup -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users'
```

Returns 'SG-HR-PayrollAndBenefits-Users'.

## PARAMETERS

### -Prefix
The first part of the group name, for example 'SG' or 'DL'.
Cannot contain whitespace.

```yaml
Type:String
Parameter Sets:   (All)
Aliases:
Required: True
Position: 1
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -Suffix
An optional last part of the group name, for example 'Users'.
Cannot contain whitespace.

```yaml
Type:String
Parameter Sets:   (All)
Aliases:
Required: False
Position: 2
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -Division
The division the group belongs to, for example 'Human Resources'.

```yaml
Type:String
Parameter Sets:   (All)
Aliases:
Required: True
Position: 3
Default value: None
Default value: None
Default value: None
Accept pipeline input: False
input:False
Accept pipeline input: False
Accept wildcard characters: False
Accept wildcard characters: False
```

### -Department
The optional department within the division, for example 'Payroll'.
When supplied, the division is
abbreviated to its initials.

```yaml
Type:String
Parameter Sets:   (All)
Aliases:
Required: False
Position: 4
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

### System.String
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS
