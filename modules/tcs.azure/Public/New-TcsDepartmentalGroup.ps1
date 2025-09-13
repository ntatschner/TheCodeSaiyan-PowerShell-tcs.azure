function New-RSYDepartmentalGroup {
    param(
        [CmdletBinding()]
        [Parameter(Mandatory)]
        [ValidateScript({ if ($_ -match '^\s$') { $false } else { $true } }, ErrorMessage = "Prefix cannot contain a space.")]
        [String]
        [ValidateNotNullOrEmpty()]
        $Prefix,
        [ValidateScript({ if ($_ -match '^\s$') { $false } else { $true } }, ErrorMessage = "Prefix cannot contain a space.")]
        [string]
        $Suffix,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Division,
        [string]
        $Department
    )
    $Group = $null
    $Division = $Division -replace '&', 'and'
    $Division = $Division -replace ',', ''
    if ($Department) {
        $Department = $Department -replace '&', 'and'
        $Division = ($Division -split ' ' | ForEach-Object { $_.Substring(0, 1).ToUpper() }) -join ''
        if ($Department -match  "$Division -") {
            $Department = $Department -replace "$Division -", ''
        }
        if ($Department -match ' ') {
            $Department = ($Department -split ' ' | ForEach-Object { if ($_.Length -gt 1) { $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()} else {$_.Substring(0).ToUpper()} }) -join ''
        }
        else {
            $Department = $Department.Substring(0, 1).ToUpper() + $Department.Substring(1).ToLower()
        }
        $Department = $Department -replace '\s', ''
        if ($Suffix) {
            $Group = "$Prefix-$Division-$Department-$Suffix"
        }
        else {
            $Group = "$Prefix-$Division-$Department"
        }
    }
    else {
        if ($Division -match ' ') {
            $Division = ($Division -split ' ' | ForEach-Object { if ($_.Length -gt 1) { $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()} else {$_.Substring(0).ToUpper()} }) -join ''
        }
        else {
            $Division = $Division.Substring(0, 1).ToUpper() + $Division.Substring(1).ToLower()
        }
        $Division = $Division -replace '\s', ''
        if ($Suffix) {
            $Group = "$Prefix-$Division-$Suffix"
        }
        else {
            $Group = "$Prefix-$Division"
        }
    }
    $Group
}
