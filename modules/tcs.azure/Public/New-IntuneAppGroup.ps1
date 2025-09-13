<#
.SYNOPSIS
Creates Intune App Groups or App Collection Groups based on the provided names.

.DESCRIPTION
The `New-IntuneAppGroup` function creates Intune App Groups or App Collection Groups for the specified names. 
It supports creating both "Available" and "Required" groups for each name provided. The function also includes 
progress reporting to indicate the status of the group creation process.

.PARAMETER Collection
A switch parameter that, when specified, indicates that App Collection Groups should be created instead of App Groups.

.PARAMETER Name
An array of strings representing the names for which the Intune groups should be created. Each name will have both 
"Available" and "Required" groups created.

.EXAMPLE
PS> New-IntuneAppGroup -Name "App1", "App2"

Creates Intune App Groups for "App1" and "App2" with both "Available" and "Required" groups.

Output:
Creating Intune Groups
Processing App1 (Available)
Group "Intune-AG-App1-Available" created.
Processing App1 (Required)
Group "Intune-AG-App1-Required" created.
Processing App2 (Available)
Group "Intune-AG-App2-Available" created.
Processing App2 (Required)
Group "Intune-AG-App2-Required" created.

.EXAMPLE
PS> New-IntuneAppGroup -Collection -Name "App1", "App2"

Creates Intune App Collection Groups for "App1" and "App2" with both "Available" and "Required" groups.

Output:
Creating Intune Groups
Processing App1 (Available)
Group "Intune-ACG-App1-Available" created.
Processing App1 (Required)
Group "Intune-ACG-App1-Required" created.
Processing App2 (Available)
Group "Intune-ACG-App2-Available" created.
Processing App2 (Required)
Group "Intune-ACG-App2-Required" created.

.NOTES
The function uses the `Get-EntraGroup` and `New-EntraGroup` cmdlets to interact with Azure AD groups. 
Ensure you have the necessary permissions to create groups in Azure AD.

#>
function New-IntuneAppGroup {
    [CmdletBinding()]
    param(
        [switch]
        $Collection,

        [string[]]
        $Name
    )
    begin {
        $totalIterations = $Name.Count * 2
        $currentIteration = 0
    }
    process {
        foreach ($a in $Name) {
            $a = $($a -split " " | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
            $Description = "Intune $(if ($Collection) { "App Collection Group" } else { "App Group" }) for `"$a`", this is an"
            foreach ($i in ("Available", "Required")) {
                $currentIteration++
                $percentComplete = ($currentIteration / $totalIterations) * 100
                Write-Progress -Activity "Creating Intune Groups" -Status "Processing $a ($i)" -PercentComplete $percentComplete
                $Params = @{
                    MailNickname = "Intune-$(if ($Collection) {"ACG"} else {"AG"})-$a-$i"
                    DisplayName  = "Intune-$(if ($Collection) {"ACG"} else {"AG"})-$a-$i"
                    Description  = "$Description $i install."
                }
                Write-Verbose "Creating Intune group `"$($Params.DisplayName)`""
                try {
                    if (Get-EntraGroup -Filter "DisplayName eq '$($Params.DisplayName)'") {
                        Write-Warning "Group `"$($Params.DisplayName)`" already exists"
                    }
                    else {
                        New-EntraGroup @Params -MailEnabled $false -SecurityEnabled $true -ErrorAction Stop
                        Write-Verbose "Group `"$($Params.DisplayName)`" created."
                    }
                }
                catch {
                    Write-Error $_
                    continue
                }
            }
        }
    }
}
