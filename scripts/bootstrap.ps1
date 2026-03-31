[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $root '.venv'
$pythonExe = Join-Path $venvPath 'Scripts\python.exe'

if (-not (Test-Path $pythonExe)) {
    Write-Host 'Creating .venv'
    python -m venv $venvPath
}

Write-Host 'Upgrading pip'
& $pythonExe -m pip install --upgrade pip

Write-Host 'Installing Python dependencies'
& $pythonExe -m pip install -r (Join-Path $root 'backend\requirements.txt') -r (Join-Path $root 'customer-python\requirements.txt') -r (Join-Path $root 'customer-python-cert\requirements.txt')

Write-Host 'Installing TypeScript dependencies'
Push-Location (Join-Path $root 'customer-typescript')
try {
    npm install
}
finally {
    Pop-Location
}

Write-Host 'Bootstrap complete'
