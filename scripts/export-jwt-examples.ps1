[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $root '.venv\Scripts\python.exe'
$scriptPath = Join-Path $root 'scripts\export-jwt-examples.py'

if (-not (Test-Path $pythonExe)) {
    throw 'Python virtual environment not found. Run .\scripts\bootstrap.ps1 first.'
}

& $pythonExe $scriptPath
