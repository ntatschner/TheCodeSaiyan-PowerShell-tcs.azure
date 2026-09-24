<#
.SYNOPSIS
    Installs tcs.core for CI: from the PowerShell Gallery when the required version is published,
    otherwise from the tcs.core repository (so this module can be tested before tcs.core is released).
#>
[CmdletBinding()]
param(
    [version]$MinimumVersion = '0.3.0',

    [string]$Ref = 'main'
)

try {
    Install-Module -Name tcs.core -MinimumVersion $MinimumVersion -Force -Scope CurrentUser -ErrorAction Stop
    Write-Output "Installed tcs.core >= $MinimumVersion from the PowerShell Gallery."
    return
}
catch {
    Write-Warning "tcs.core >= $MinimumVersion is not available from the PowerShell Gallery ($($_.Exception.Message)). Using the tcs.core repository ($Ref) instead."
}

$source = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'tcs-core-src'
if (Test-Path -Path $source) {
    Remove-Item -Path $source -Recurse -Force
}
git clone --quiet --depth 1 --branch $Ref https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.core.git $source
if ($LASTEXITCODE -ne 0) {
    throw "Cloning tcs.core ($Ref) failed."
}

$modulesPath = Join-Path -Path $source -ChildPath 'modules'
$manifest = Join-Path -Path (Join-Path -Path $modulesPath -ChildPath 'tcs.core') -ChildPath 'tcs.core.psd1'
$version = [version](Import-PowerShellDataFile -Path $manifest).ModuleVersion
if ($version -lt $MinimumVersion) {
    throw "tcs.core on '$Ref' is $version; this module needs >= $MinimumVersion. Merge the tcs.core release first."
}

# Make the module resolvable for the following workflow steps
$newPath = $modulesPath + [System.IO.Path]::PathSeparator + $env:PSModulePath
Add-Content -Path $env:GITHUB_ENV -Value "PSModulePath=$newPath"
Write-Output "Using tcs.core $version from the tcs.core repository ($Ref)."
