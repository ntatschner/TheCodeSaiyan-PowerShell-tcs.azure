<#
.SYNOPSIS
    Converts an Entra ID group into a Tcs.Azure.IntuneAppGroup object.

.DESCRIPTION
    Private helper for Get-IntuneAppGroup. The application name and intent are read from the group
    name ('Intune-AG-<AppName>-<Intent>'); they are empty for a name that does not follow the pattern.

.PARAMETER Group
    A group object returned by Get-EntraGroup.
#>
function ConvertTo-IntuneAppGroupObject {
    [CmdletBinding()]
    [OutputType('Tcs.Azure.IntuneAppGroup')]
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $Group
    )

    $displayName = [string]$Group.DisplayName
    $appName = $null
    $intent = $null
    $match = [regex]::Match($displayName, '^Intune-(?:AG|ACG)-(.+)-(Available|Required|Uninstall)$', 'IgnoreCase, CultureInvariant')
    if ($match.Success) {
        $appName = $match.Groups[1].Value
        $intent = $match.Groups[2].Value
    }
    $result = [pscustomobject]@{
        PSTypeName   = 'Tcs.Azure.IntuneAppGroup'
        Name         = $displayName
        Id           = $Group.Id
        AppName      = $appName
        Intent       = $intent
        Status       = 'Existing'
        MailNickname = $Group.MailNickname
    }
    $result | Add-Member -MemberType AliasProperty -Name DisplayName -Value Name
    $result
}
