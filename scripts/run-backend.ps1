[CmdletBinding()]
param(
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $root '.venv\Scripts\python.exe'

if (-not (Test-Path $pythonExe)) {
    throw 'Python virtual environment not found. Run .\scripts\bootstrap.ps1 first.'
}

& $pythonExe -m uvicorn backend.app.main:app --host 127.0.0.1 --port $Port
