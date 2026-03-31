[CmdletBinding()]
param(
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $root '.venv\Scripts\python.exe'
$backendUrl = "http://127.0.0.1:$Port"
$stdoutLog = Join-Path $root '.backend.stdout.log'
$stderrLog = Join-Path $root '.backend.stderr.log'
$customerDefinitionsPath = Join-Path $root 'customers.json'

if (-not (Test-Path $pythonExe)) {
    throw 'Python virtual environment not found. Run .\scripts\bootstrap.ps1 first.'
}

function Wait-ForBackend {
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri "$backendUrl/health" -TimeoutSec 5
            if ($health.status -eq 'ok') {
                return $health
            }
        }
        catch {
        }

        Start-Sleep -Seconds 2
    }

    $stdoutText = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Raw } else { '' }
    $stderrText = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw } else { '' }
    throw "Backend did not become healthy. Stdout: $stdoutText`nStderr: $stderrText"
}

function Invoke-Retry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [Parameter(Mandatory = $true)][string]$OperationName,
        [int]$MaxAttempts = 8,
        [int]$DelaySeconds = 10
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $output = & $Script 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            return $output | ConvertFrom-Json
        }

        if ($attempt -eq $MaxAttempts) {
            throw "$OperationName failed after $MaxAttempts attempts. Output: $output"
        }

        Start-Sleep -Seconds $DelaySeconds
    }
}

function Get-CustomerDefinitions {
    if (-not (Test-Path $customerDefinitionsPath)) {
        throw "Customer definitions file was not found: $customerDefinitionsPath"
    }

    $definitions = (Get-Content -Path $customerDefinitionsPath -Raw | ConvertFrom-Json).customers
    if ($null -eq $definitions -or @($definitions).Count -eq 0) {
        throw "Customer definitions file did not contain any customers: $customerDefinitionsPath"
    }

    return @($definitions)
}

function Invoke-CustomerApplication {
    param([Parameter(Mandatory = $true)][object]$Customer)

    $runtime = [string]$Customer.runtime
    switch ($runtime.ToLowerInvariant()) {
        'python' {
            $entryPoint = Join-Path $root ([string]$Customer.entryPoint)
            return & $pythonExe $entryPoint
        }
        'typescript' {
            $workingDirectory = Join-Path $root ([string]$Customer.workingDirectory)
            Push-Location $workingDirectory
            try {
                return npm run --silent dev
            }
            finally {
                Pop-Location
            }
        }
        default {
            throw "Unsupported customer runtime '$runtime' for customer '$($Customer.customerId)'."
        }
    }
}

$backendProcess = Start-Process -FilePath $pythonExe -ArgumentList '-m', 'uvicorn', 'backend.app.main:app', '--host', '127.0.0.1', '--port', $Port.ToString() -WorkingDirectory $root -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru

try {
    $health = Wait-ForBackend

    $customerResults = @()
    foreach ($customer in Get-CustomerDefinitions) {
        $customerResult = Invoke-Retry -OperationName "$($customer.customerId) app" -Script {
            Invoke-CustomerApplication -Customer $customer
        }

        $customerResults += [pscustomobject]@{
            customerId = $customerResult.customer_id
            recordCount = @($customerResult.records).Count
        }
    }

    $summary = [pscustomobject]@{
        backend = $health
        customers = $customerResults
    }

    $summary | ConvertTo-Json -Depth 6
}
finally {
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force
    }
}
