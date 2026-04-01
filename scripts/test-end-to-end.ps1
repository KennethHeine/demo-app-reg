[CmdletBinding()]
param(
    [int]$Port = 8000,
    [string]$ApiBaseUrl,
    [switch]$UseLocalBackend,
    [string]$ResourceGroupName = 'demo-app-reg',
    [string]$ContainerAppName = 'demo-app-reg-backend'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $root '.venv\Scripts\python.exe'
$stdoutLog = Join-Path $root '.backend.stdout.log'
$stderrLog = Join-Path $root '.backend.stderr.log'
$customerDefinitionsPath = Join-Path $root 'customers.json'

if (-not (Test-Path $pythonExe)) {
    throw 'Python virtual environment not found. Run .\scripts\bootstrap.ps1 first.'
}

if ($UseLocalBackend -and -not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    throw 'Do not pass -ApiBaseUrl together with -UseLocalBackend.'
}

function Resolve-RemoteBackendUrl {
    param(
        [Parameter(Mandatory = $false)][string]$ExplicitUrl,
        [Parameter(Mandatory = $true)][string]$GroupName,
        [Parameter(Mandatory = $true)][string]$AppName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitUrl)) {
        return $ExplicitUrl.TrimEnd('/')
    }

    $azCommand = Get-Command az -ErrorAction SilentlyContinue
    if ($null -eq $azCommand) {
        throw 'Azure CLI was not found. Install Azure CLI, pass -ApiBaseUrl explicitly, or use -UseLocalBackend.'
    }

    $fqdn = az containerapp show --name $AppName --resource-group $GroupName --query 'properties.configuration.ingress.fqdn' --output tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($fqdn)) {
        throw "Failed to resolve the live Container App URL for '$AppName' in resource group '$GroupName'. Pass -ApiBaseUrl explicitly or use -UseLocalBackend."
    }

    return "https://$($fqdn.Trim())"
}

$useRemoteBackend = -not $UseLocalBackend
$backendUrl = if ($UseLocalBackend) {
    "http://127.0.0.1:$Port"
}
else {
    Resolve-RemoteBackendUrl -ExplicitUrl $ApiBaseUrl -GroupName $ResourceGroupName -AppName $ContainerAppName
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

    if ($useRemoteBackend) {
        throw "Backend did not become healthy at $backendUrl. Pass -ApiBaseUrl explicitly if you want a different live URL, or use -UseLocalBackend for the local backend."
    }

    $stdoutText = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Raw } else { '' }
    $stderrText = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw } else { '' }
    throw "Backend did not become healthy. Stdout: $stdoutText`nStderr: $stderrText"
}

function Write-TestStep {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'PASS')][string]$Level = 'INFO'
    )

    Write-Host "[$Level] $Message"
}

function Invoke-HttpExpectation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ExpectedStatusCode,
        [Parameter(Mandatory = $true)][string]$Description
    )

    Write-TestStep -Message $Description
    $response = Invoke-WebRequest -Uri "$backendUrl$Path" -Method Get -TimeoutSec 15 -SkipHttpErrorCheck
    $statusCode = [int]$response.StatusCode
    if ($statusCode -ne $ExpectedStatusCode) {
        throw "Expected HTTP $ExpectedStatusCode for '$Path' but got $statusCode. Response body: $($response.Content)"
    }

    $result = [pscustomobject]@{
        path = $Path
        statusCode = $statusCode
        expectedStatusCode = $ExpectedStatusCode
        body = ($response.Content | Out-String).Trim()
    }

    Write-TestStep -Level 'PASS' -Message "$Path returned HTTP $statusCode as expected"
    return $result
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

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [Parameter(Mandatory = $true)][string]$OperationName,
        [Parameter(Mandatory = $true)][string]$FailurePattern,
        [int]$MaxAttempts = 8,
        [int]$DelaySeconds = 10
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $output = & $Script 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -and $output -match $FailurePattern) {
            $structuredError = $null
            try {
                $structuredError = $output | ConvertFrom-Json
            }
            catch {
            }

            return [pscustomobject]@{
                output = $output.Trim()
                structuredError = $structuredError
            }
        }

        if ($attempt -eq $MaxAttempts) {
            throw "$OperationName did not produce the expected failure after $MaxAttempts attempts. Output: $output"
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

function Get-CustomerRoleAssignment {
    param([Parameter(Mandatory = $true)][object]$Customer)

    $roleAssignment = [string]$Customer.roleAssignment
    if ([string]::IsNullOrWhiteSpace($roleAssignment)) {
        return 'assigned'
    }

    $normalizedValue = $roleAssignment.Trim().ToLowerInvariant()
    if ($normalizedValue -notin @('assigned', 'not-assigned')) {
        throw "Unsupported roleAssignment '$roleAssignment' for customer '$($Customer.customerId)'."
    }

    return $normalizedValue
}

function Invoke-CustomerApplication {
    param([Parameter(Mandatory = $true)][object]$Customer)

    $previousApiBaseUrlOverride = [System.Environment]::GetEnvironmentVariable('API_BASE_URL_OVERRIDE', 'Process')
    $runtime = [string]$Customer.runtime
    try {
        [System.Environment]::SetEnvironmentVariable('API_BASE_URL_OVERRIDE', $backendUrl, 'Process')

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
    finally {
        [System.Environment]::SetEnvironmentVariable('API_BASE_URL_OVERRIDE', $previousApiBaseUrlOverride, 'Process')
    }
}

$backendProcess = $null

try {
    if (-not $useRemoteBackend) {
        Write-TestStep -Message "Starting local backend on $backendUrl"
        $backendProcess = Start-Process -FilePath $pythonExe -ArgumentList '-m', 'uvicorn', 'backend.app.main:app', '--host', '127.0.0.1', '--port', $Port.ToString() -WorkingDirectory $root -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru
    }
    elseif (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        Write-TestStep -Message "Using remote backend at $backendUrl"
    }
    else {
        Write-TestStep -Message "Using live backend resolved from Azure at $backendUrl"
    }

    Write-TestStep -Message 'Waiting for backend health check to succeed'
    $health = Wait-ForBackend
    Write-TestStep -Level 'PASS' -Message "Backend health check succeeded with status '$($health.status)'"

    $unauthenticatedChecks = @()
    $unauthenticatedChecks += Invoke-HttpExpectation -Path '/customer-data' -ExpectedStatusCode 401 -Description 'Running unauthenticated check for /customer-data'

    if ($useRemoteBackend) {
        $unauthenticatedChecks += Invoke-HttpExpectation -Path '/.auth/me' -ExpectedStatusCode 401 -Description 'Running unauthenticated check for /.auth/me'
    }

    $customerResults = @()
    foreach ($customer in Get-CustomerDefinitions) {
        $roleAssignment = Get-CustomerRoleAssignment -Customer $customer
        if ($roleAssignment -eq 'assigned') {
            Write-TestStep -Message "Running assigned customer flow for $($customer.customerId)"
            $customerResult = Invoke-Retry -OperationName "$($customer.customerId) app" -Script {
                Invoke-CustomerApplication -Customer $customer
            }

            $customerSummary = [pscustomobject]@{
                customerId = $customerResult.customer_id
                roleAssignment = $roleAssignment
                result = 'success'
                recordCount = @($customerResult.records).Count
            }
            $customerResults += $customerSummary
            Write-TestStep -Level 'PASS' -Message "$($customerSummary.customerId) completed successfully with $($customerSummary.recordCount) records"
        }
        else {
            Write-TestStep -Message "Running expected token-denied flow for $($customer.customerId)"
            $failureResult = Invoke-ExpectedFailure -OperationName "$($customer.customerId) app" -FailurePattern 'AADSTS501051|not assigned to a role' -Script {
                Invoke-CustomerApplication -Customer $customer
            }

            $errorCode = if ($null -ne $failureResult.structuredError -and $null -ne $failureResult.structuredError.error_codes) {
                @($failureResult.structuredError.error_codes | ForEach-Object { [string]$_ }) -join ','
            }
            else {
                'n/a'
            }

            $customerSummary = [pscustomobject]@{
                customerId = [string]$customer.customerId
                roleAssignment = $roleAssignment
                result = 'expected-token-denied'
                error = if ($null -ne $failureResult.structuredError) { [string]$failureResult.structuredError.error } else { 'n/a' }
                errorCode = $errorCode
                errorDescription = if ($null -ne $failureResult.structuredError) { [string]$failureResult.structuredError.error_description } else { $failureResult.output }
            }
            $customerResults += $customerSummary
            Write-TestStep -Level 'PASS' -Message "$($customerSummary.customerId) failed as expected because it is not assigned to the backend app role"
        }
    }

    $summary = [pscustomobject]@{
        backend = [pscustomobject]@{
            mode = if ($useRemoteBackend) { 'remote' } else { 'local' }
            url = $backendUrl
            health = $health
        }
        unauthenticatedChecks = $unauthenticatedChecks
        customers = $customerResults
    }

    $summary | ConvertTo-Json -Depth 6
}
finally {
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force
    }
}
