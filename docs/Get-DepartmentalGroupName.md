---
external help file: tcs.azure-help.xml
Module Name: tcs.azure
online version:
schema: 2.0.0
---

# Get-DepartmentalGroupName

## SYNOPSIS
Builds a standardised departmental group name.

## SYNTAX

```
Get-DepartmentalGroupName [-Prefix] <String> [[-Suffix] <String>] [-Division] <String> [[-Department] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-DepartmentalGroupName function builds a group name from a prefix, a division, an optional
department and an optional suffix, separated by hyphens.
It only returns the name; it does not
create anything in Microsoft Entra ID or Azure (use New-TcsEntraDepartmentalGroup for that).

This command was called New-TcsDepartmentalGroup before version 0.2.0; that name still works as an alias.

Naming rules:
  - '&' is read as 'and'.
Apostrophes are removed ("Children's" -\> 'Childrens').
Any other character
    that is not a letter, digit, space or hyphen (for example , ( ) / \ .
:) is treated as a space.
  - Words are joined in PascalCase: the first letter of each word is upper-cased and the rest is kept
    as written, so acronyms stay as they are ('IT' -\> 'IT', 'human resources' -\> 'HumanResources').
    Culture-independent (invariant) casing is used, so the result is the same under any culture.
  - A hyphen inside a word ('E-Commerce') is kept.
A hyphen on its own, or at the start or end of a
    word, separates parts of the name: 'Accounts Payable - UK' -\> 'AccountsPayable-UK'.
Stray
    hyphens and empty parts are dropped ('HR -' -\> 'HR').
  - Without a department, the division is used in full ('SG-HumanResources').
  - With a department, the division is abbreviated to the initials of its words and the department
    is written in PascalCase ('SG-HR-Payroll').
All-caps words of 2 to 4 characters (acronyms) are
    kept whole in the initials ('IT Services' -\> 'ITS'), and the words and, of, the and & are
    skipped ('Sales & Marketing' -\> 'SM').
    Leading parts of the department that repeat the initials or the division ('HR - Payroll') are removed.
  - A part that repeats the part before it is not added twice ('HR' with department 'HR' -\> 'SG-HR').
  - A division with no letters or digits left after clean-up (for example ',' or '&') is rejected
    with an error.

## EXAMPLES

### EXAMPLE 1
```
Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources'
```

Returns 'SG-HumanResources'.

### EXAMPLE 2
```
Get-DepartmentalGroupName -Prefix 'SG' -Division 'Human Resources' -Department 'HR - Payroll & Benefits' -Suffix 'Users'
```

Returns 'SG-HR-PayrollAndBenefits-Users'.

### EXAMPLE 3
```
Import-Csv .\departments.csv | Get-DepartmentalGroupName -Prefix 'SG'
```

Returns one name for each row; the CSV has Division and Department columns.

## PARAMETERS

### -Prefix
The first part of the group name, for example 'SG' or 'DL'.
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
property name, so a CSV with a Division column can be piped in.

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
When supplied, the division is
abbreviated to its initials.
Accepts pipeline input by property name.

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

### System.String
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS
