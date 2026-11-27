<#
.SYNOPSIS
    Regenerates Database\Generated\CVarCatalog.lua from the latest research sources.

.DESCRIPTION
    Clones (or updates) Ketho/BlizzardInterfaceResources and Gethe/wow-ui-source on their
    `forever` branches into a cache folder outside the repo, copies the CVar dump into
    tools\database\sources, and runs the importer with the source revisions and builds recorded.

.PARAMETER CacheDir
    Where to keep the source checkouts (default: %LOCALAPPDATA%\EverSettings\sources).
#>
param([string]$CacheDir = (Join-Path $env:LOCALAPPDATA 'EverSettings\sources'))

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

function Sync-Repo($url, $dir) {
    if (Test-Path (Join-Path $dir '.git')) {
        git -C $dir fetch --depth 1 origin forever | Out-Null
        git -C $dir reset --hard origin/forever | Out-Null
    } else {
        git clone --depth 1 -b forever $url $dir | Out-Null
    }
    return (git -C $dir rev-parse HEAD).Trim()
}

$bir = Join-Path $CacheDir 'BlizzardInterfaceResources'
$ui = Join-Path $CacheDir 'wow-ui-source'
$birRev = Sync-Repo 'https://github.com/Ketho/BlizzardInterfaceResources.git' $bir
$uiRev = Sync-Repo 'https://github.com/Gethe/wow-ui-source.git' $ui

# Build numbers: the README of Ketho's repo states GetBuildInfo(); wow-ui-source has version.txt.
$birReadme = Get-Content (Join-Path $bir 'README.md') -Raw
$birBuild = if ($birReadme -match '"(\d+\.\d+\.\d+)",\s*"(\d+)"') { "$($Matches[1]).$($Matches[2])" } else { 'unknown' }
$uiBuild = (Get-Content (Join-Path $ui 'version.txt') -Raw).Trim()

Copy-Item (Join-Path $bir 'Resources\CVars.lua') (Join-Path $repo 'tools\database\sources\CVars.forever.lua') -Force

$python = Join-Path $repo '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { $python = 'python' }
& $python -I (Join-Path $repo 'tools\database\import_cvars.py') `
    --ui-source $ui --cvars-rev $birRev --cvars-build $birBuild --ui-rev $uiRev --ui-build $uiBuild
exit $LASTEXITCODE
