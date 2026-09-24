<#
.SYNOPSIS
    Finds Intune app assignment groups in Microsoft Entra ID.

.DESCRIPTION
    Private helper for Get-IntuneAppGroup and Remove-IntuneAppGroup. Queries Get-EntraGroup with a
    startswith filter on the 'Intune-AG-' and 'Intune-ACG-' prefixes (one query each, all pages).
    With -AppName (already in PascalCase) only groups named exactly
    'Intune-AG|ACG-<AppName>-Available|Required|Uninstall' are returned, so 'App' does not match
    'Intune-AG-App-Extra-Available'. Returns the group objects from Get-EntraGroup.

.PARAMETER AppName
    The application name part of the group name, in PascalCase. Omit it to return every group with
    the Intune-AG- or Intune-ACG- prefix.
#>
function Find-IntuneAppGroup {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string]
        $AppName
    )

    foreach ($prefix in @('Intune-AG-', 'Intune-ACG-')) {
        $start = $prefix
        if ($AppName) {
            $start = "$prefix$AppName-"
        }
        # Single quotes are doubled so the name is a valid OData string literal
        $filter = "startswith(displayName,'$($start -replace "'", "''")')"
        foreach ($group in @(Get-EntraGroup -Filter $filter -All -ErrorAction Stop)) {
            if (-not $group) {
                continue
            }
            if ($AppName) {
                $pattern = '^' + [regex]::Escape($prefix + $AppName) + '-(Available|Required|Uninstall)$'
                if (-not [regex]::IsMatch([string]$group.DisplayName, $pattern, 'IgnoreCase, CultureInvariant')) {
                    continue
                }
            }
            $group
        }
    }
}
