<#
.SYNOPSIS
    Runs the offline test suite (creates .venv with lupa on first use).
.EXAMPLE
    .\scripts\test.ps1           # all specs
    .\scripts\test.ps1 -v ui     # verbose, only specs whose file name contains "ui"
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$venvPython = Join-Path $repo '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    python -m venv (Join-Path $repo '.venv')
    & $venvPython -m pip install --quiet lupa
}
& $venvPython -I (Join-Path $repo 'tests\run_tests.py') @args
exit $LASTEXITCODE
