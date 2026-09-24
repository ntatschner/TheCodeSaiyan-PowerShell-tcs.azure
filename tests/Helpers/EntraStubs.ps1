# Pester can only mock commands that exist. When the Microsoft Entra module is not installed, this
# defines global stand-ins with the parameters the tcs.azure commands use. Returns the names it defined
# so the caller can remove them in AfterAll. Dot-source it from BeforeAll.
function Add-TcsEntraStub {
    $created = @()
    $stubs = [ordered]@{
        'Get-EntraContext'    = { [CmdletBinding()] param() }
        'Get-EntraGroup'      = { [CmdletBinding()] param([string]$Filter, [string]$GroupId, [switch]$All) $null = $PSBoundParameters }
        'New-EntraGroup'      = {
            [CmdletBinding()]
            param([string]$DisplayName, [string]$MailNickname, [string]$Description, [bool]$MailEnabled, [bool]$SecurityEnabled,
                [string[]]$GroupTypes, [string]$MembershipRule, [string]$MembershipRuleProcessingState)
            $null = $PSBoundParameters
        }
        'Remove-EntraGroup'   = { [CmdletBinding()] param([string]$GroupId) $null = $PSBoundParameters }
        'Add-EntraGroupOwner' = { [CmdletBinding()] param([string]$GroupId, [string]$OwnerId) $null = $PSBoundParameters }
    }
    foreach ($name in $stubs.Keys) {
        if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) {
            Set-Item -Path "Function:\global:$name" -Value $stubs[$name]
            $created += $name
        }
    }
    $created
}

function Remove-TcsEntraStub {
    param([string[]]$Name)
    foreach ($stub in $Name) {
        Remove-Item -Path "Function:\$stub" -ErrorAction SilentlyContinue
    }
}
