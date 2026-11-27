<#
.SYNOPSIS
    Deploys the EverSettings addon into the WoW: Forever AddOns folder.

.DESCRIPTION
    Copies (default) or links addon\EverSettings into <WoW>\_forever_\Interface\AddOns\EverSettings.

    The WoW install is resolved in this order:
      1. -WowPath parameter
      2. EVERSETTINGS_WOW_PATH environment variable
      3. scripts\deploy.local.json  ->  { "wowPath": "D:\\Games\\World of Warcraft" }   (git-ignored)
      4. Blizzard's registry key, then common install locations

    -WowPath may point at the World of Warcraft folder or directly at its _forever_ folder.

.PARAMETER Mode
    copy (default): mirror the addon folder (robocopy /MIR) - what players get.
    link: create a directory junction so edits in the repo are live after /reload.

.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -Mode link
    .\scripts\deploy.ps1 -WowPath "D:\Games\World of Warcraft"
#>
[CmdletBinding()]
param(
    [string]$WowPath,
    [ValidateSet('copy', 'link')]
    [string]$Mode = 'copy'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'addon\EverSettings'
if (-not (Test-Path (Join-Path $source 'EverSettings.toc'))) {
    throw "Addon source not found at $source"
}

function Resolve-ForeverRoot([string]$path) {
    if (-not $path) { return $null }
    if (-not (Test-Path $path)) { return $null }
    if ((Split-Path -Leaf $path) -eq '_forever_') { return (Resolve-Path $path).Path }
    $candidate = Join-Path $path '_forever_'
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    return $null
}

$forever = $null
$origin = $null
if ($WowPath) { $forever = Resolve-ForeverRoot $WowPath; $origin = '-WowPath' }
if (-not $forever -and $env:EVERSETTINGS_WOW_PATH) { $forever = Resolve-ForeverRoot $env:EVERSETTINGS_WOW_PATH; $origin = 'EVERSETTINGS_WOW_PATH' }
if (-not $forever) {
    $localConfig = Join-Path $PSScriptRoot 'deploy.local.json'
    if (Test-Path $localConfig) {
        $cfg = Get-Content $localConfig -Raw | ConvertFrom-Json
        $forever = Resolve-ForeverRoot $cfg.wowPath
        $origin = 'deploy.local.json'
    }
}
if (-not $forever) {
    $candidates = @()
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
        try {
            $installPath = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
            if ($installPath) { $candidates += (Split-Path -Parent $installPath.TrimEnd('\')); $candidates += $installPath }
        } catch {}
    }
    $candidates += @(
        "${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft",
        'C:\World of Warcraft', 'D:\World of Warcraft', 'E:\World of Warcraft', 'F:\World of Warcraft',
        'D:\Games\World of Warcraft', 'E:\Games\World of Warcraft', 'F:\Games\World of Warcraft'
    )
    foreach ($c in $candidates) {
        $forever = Resolve-ForeverRoot $c
        if ($forever) { $origin = "auto-detected ($c)"; break }
    }
}
if (-not $forever) {
    throw "Could not find a WoW Forever install (_forever_ folder). Pass -WowPath, set EVERSETTINGS_WOW_PATH, or create scripts\deploy.local.json."
}

$addons = Join-Path $forever 'Interface\AddOns'
if (-not (Test-Path $addons)) { New-Item -ItemType Directory -Path $addons -Force | Out-Null }
$target = Join-Path $addons 'EverSettings'
Write-Host "Forever install: $forever  [$origin]"
Write-Host "Target:          $target  [mode: $Mode]"

# Safety: only ever touch a folder literally named EverSettings inside Interface\AddOns.
if ((Split-Path -Leaf $target) -ne 'EverSettings' -or (Split-Path -Leaf (Split-Path -Parent $target)) -ne 'AddOns') {
    throw "Refusing to deploy to unexpected path $target"
}

$item = Get-Item $target -ErrorAction SilentlyContinue
$isLink = $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)

if ($Mode -eq 'link') {
    if ($item -and -not $isLink) {
        throw "$target exists as a normal folder. Remove it (or run with -Mode copy) before linking."
    }
    if ($isLink) { cmd /c rmdir "$target" | Out-Null }
    cmd /c mklink /J "$target" "$source" | Out-Null
    Write-Host "Linked. Edits in the repo take effect after /reload in game."
} else {
    if ($isLink) { cmd /c rmdir "$target" | Out-Null }
    robocopy $source $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    $global:LASTEXITCODE = 0
    $count = (Get-ChildItem $target -Recurse -File).Count
    Write-Host "Copied $count files. Type /reload in game (or restart the client) to load the new version."
}
