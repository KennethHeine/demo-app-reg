[CmdletBinding()]
param(
    [string]$Prefix = 'demo-app-reg',
    [string]$ApiDomain = 'kscloud.io',
    [string]$DeploymentLocation = 'westeurope',
    [string]$TemplateFilePath = 'infra/entra-backend-api.bicep',
    [string]$ParameterFilePath = 'infra/entra-backend-api.parameters.json',
    [string]$KeyVaultName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$entraConfigPath = Join-Path $root 'entra-config.local.json'
$backendEnvPath = Join-Path $root 'backend\.env'

function Resolve-WorkspacePath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-JsonFileIfExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Write-EnvFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $directoryPath = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    }

    $content = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
    Set-Content -Path $Path -Value $content -Encoding utf8
}

function New-DeploymentParametersFile {
    param(
        [Parameter(Mandatory = $true)][string]$BaseParameterFilePath,
        [Parameter(Mandatory = $true)][hashtable]$OverrideValues
    )

    $baseDocument = Get-Content -Path $BaseParameterFilePath -Raw | ConvertFrom-Json
    $parameterDocument = [ordered]@{
        '$schema' = $baseDocument.'$schema'
        contentVersion = $baseDocument.contentVersion
        parameters = [ordered]@{}
    }

    foreach ($property in $baseDocument.parameters.PSObject.Properties) {
        $parameterDocument.parameters[$property.Name] = @{
            value = $property.Value.value
        }
    }

    foreach ($entry in $OverrideValues.GetEnumerator()) {
        $parameterDocument.parameters[$entry.Key] = @{
            value = $entry.Value
        }
    }

    $tempFilePath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "demo-app-reg.entra.$([System.Guid]::NewGuid().ToString('N')).parameters.json"
    )

    $parameterDocument | ConvertTo-Json -Depth 20 | Set-Content -Path $tempFilePath -Encoding UTF8
    return $tempFilePath
}

function Get-AzureAccountContext {
    $accountJson = az account show --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
        throw 'Azure CLI is not logged in. Run az login before deploying the backend Entra app registration.'
    }

    return $accountJson | ConvertFrom-Json
}

function Get-ApplicationByAppIdOrNull {
    param([Parameter(Mandatory = $true)][string]$AppId)

    $applicationJson = az ad app show --id $AppId --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($applicationJson)) {
        return $null
    }

    return $applicationJson | ConvertFrom-Json
}

function Get-ApplicationsByDisplayName {
    param([Parameter(Mandatory = $true)][string]$DisplayName)

    $applicationsJson = az ad app list --display-name $DisplayName --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($applicationsJson)) {
        throw "Failed to query Microsoft Entra applications named '$DisplayName'."
    }

    return @($applicationsJson | ConvertFrom-Json)
}

function Assert-BackendApplicationCanBeManaged {
    param(
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$IdentifierUri,
        [Parameter(Mandatory = $true)][string]$UniqueName,
        [string]$ConfiguredAppId
    )

    $matchingApplications = @(
        Get-ApplicationsByDisplayName -DisplayName $DisplayName | Where-Object {
            (@($_.identifierUris) -contains $IdentifierUri) -or ((-not [string]::IsNullOrWhiteSpace($ConfiguredAppId)) -and ([string]$_.appId -eq $ConfiguredAppId))
        }
    )

    if ($matchingApplications.Count -eq 0) {
        return
    }

    $bicepManagedApplication = $matchingApplications | Where-Object { [string]$_.uniqueName -eq $UniqueName } | Select-Object -First 1
    if ($null -ne $bicepManagedApplication) {
        return
    }

    $legacyApplication = $matchingApplications | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace([string]$legacyApplication.uniqueName)) {
        throw "The backend app registration '$DisplayName' already exists with identifier URI '$IdentifierUri' but its uniqueName is empty. Microsoft Graph Bicep cannot safely adopt this existing app without risking a duplicate registration. Keep using scripts/setup-entra.ps1 for this tenant, or deploy the Bicep template into a clean tenant or a new backend app registration."
    }

    throw "Found an existing backend app registration '$DisplayName' that does not match the expected Graph Bicep uniqueName '$UniqueName'. Update the template inputs or remove the conflicting app before deploying."
}

function Invoke-TenantDeployment {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Location,
        [Parameter(Mandatory = $true)][string]$TemplateFilePath,
        [Parameter(Mandatory = $true)][string]$BaseParameterFilePath,
        [Parameter(Mandatory = $true)][hashtable]$OverrideValues
    )

    $tempParameterFilePath = New-DeploymentParametersFile -BaseParameterFilePath $BaseParameterFilePath -OverrideValues $OverrideValues

    try {
        $deploymentJson = az deployment tenant create `
            --name $Name `
            --location $Location `
            --template-file $TemplateFilePath `
            --parameters "@$tempParameterFilePath" `
            --output json

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($deploymentJson)) {
            throw "Deployment '$Name' failed."
        }

        return $deploymentJson | ConvertFrom-Json
    }
    finally {
        if (Test-Path $tempParameterFilePath) {
            Remove-Item -Path $tempParameterFilePath -Force
        }
    }
}

function Set-EntraConfigFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)][string]$BackendDisplayName,
        [Parameter(Mandatory = $true)][string]$BackendAppId,
        [Parameter(Mandatory = $true)][string]$BackendServicePrincipalId,
        [Parameter(Mandatory = $true)][string]$BackendIdentifierUri,
        [Parameter(Mandatory = $true)][string]$RequiredAppRoleValue,
        [Parameter(Mandatory = $true)][string]$RequiredAppRoleId,
        [Parameter(Mandatory = $true)][bool]$AssignmentRequired,
        [string]$ResolvedKeyVaultName
    )

    $existingConfig = Read-JsonFileIfExists -Path $Path
    $existingKeyVaultName = if ($null -ne $existingConfig -and $null -ne $existingConfig.keyVault) { [string]$existingConfig.keyVault.name } else { '' }
    $effectiveKeyVaultName = if (-not [string]::IsNullOrWhiteSpace($ResolvedKeyVaultName)) { $ResolvedKeyVaultName } else { $existingKeyVaultName }
    $customerRegistryPath = if ($null -ne $existingConfig -and -not [string]::IsNullOrWhiteSpace([string]$existingConfig.customerRegistryPath)) {
        [string]$existingConfig.customerRegistryPath
    }
    else {
        Join-Path $root 'backend\customer-registry.local.json'
    }

    $configDocument = [ordered]@{
        tenantId = $TenantId
        apiScope = "$BackendIdentifierUri/.default"
        customerDefinitionsPath = if ($null -ne $existingConfig -and -not [string]::IsNullOrWhiteSpace([string]$existingConfig.customerDefinitionsPath)) { [string]$existingConfig.customerDefinitionsPath } else { $null }
        keyVault = if ([string]::IsNullOrWhiteSpace($effectiveKeyVaultName)) {
            $null
        }
        else {
            [ordered]@{
                name = $effectiveKeyVaultName
                resourceGroupName = if ($null -ne $existingConfig -and $null -ne $existingConfig.keyVault) { [string]$existingConfig.keyVault.resourceGroupName } else { $null }
                vaultUri = if ($null -ne $existingConfig -and $null -ne $existingConfig.keyVault) { [string]$existingConfig.keyVault.vaultUri } else { $null }
            }
        }
        backend = [ordered]@{
            displayName = $BackendDisplayName
            appId = $BackendAppId
            servicePrincipalId = $BackendServicePrincipalId
            identifierUri = $BackendIdentifierUri
            requiredAppRoleValue = $RequiredAppRoleValue
            requiredAppRoleId = $RequiredAppRoleId
            assignmentRequired = $AssignmentRequired
        }
        customers = if ($null -ne $existingConfig -and $null -ne $existingConfig.customers) { @($existingConfig.customers) } else { @() }
        customerRegistryPath = $customerRegistryPath
        envFiles = [ordered]@{
            backend = $backendEnvPath
            customers = if ($null -ne $existingConfig -and $null -ne $existingConfig.envFiles -and $null -ne $existingConfig.envFiles.customers) { @($existingConfig.envFiles.customers) } else { @() }
        }
    }

    $configDocument | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding utf8
}

$resolvedTemplateFilePath = Resolve-WorkspacePath -PathValue $TemplateFilePath
$resolvedParameterFilePath = Resolve-WorkspacePath -PathValue $ParameterFilePath

if (-not (Test-Path $resolvedTemplateFilePath)) {
    throw "Template file was not found: $resolvedTemplateFilePath"
}

if (-not (Test-Path $resolvedParameterFilePath)) {
    throw "Parameter file was not found: $resolvedParameterFilePath"
}

$backendDisplayName = "$Prefix-backend-api"
$backendUniqueName = $backendDisplayName.ToLowerInvariant()
$backendIdentifierUri = "api://$ApiDomain/$backendDisplayName"
$existingConfig = Read-JsonFileIfExists -Path $entraConfigPath
$configuredAppId = if ($null -ne $existingConfig -and $null -ne $existingConfig.backend) { [string]$existingConfig.backend.appId } else { '' }

if (-not [string]::IsNullOrWhiteSpace($configuredAppId)) {
    $configuredApplication = Get-ApplicationByAppIdOrNull -AppId $configuredAppId
    if ($null -ne $configuredApplication -and [string]::IsNullOrWhiteSpace([string]$configuredApplication.uniqueName)) {
        throw "The configured backend app registration '$backendDisplayName' was created outside Microsoft Graph Bicep and has uniqueName set to null. This script will not replace it automatically because that would create a duplicate app registration. Keep using scripts/setup-entra.ps1 for this tenant, or migrate to a fresh Bicep-managed backend registration first."
    }
}

Assert-BackendApplicationCanBeManaged -DisplayName $backendDisplayName -IdentifierUri $backendIdentifierUri -UniqueName $backendUniqueName -ConfiguredAppId $configuredAppId

$account = Get-AzureAccountContext
$deploymentStamp = Get-Date -Format 'yyyyMMddHHmmss'
$tenantDeployment = Invoke-TenantDeployment `
    -Name "demo-app-reg-backend-entra-$deploymentStamp" `
    -Location $DeploymentLocation `
    -TemplateFilePath $resolvedTemplateFilePath `
    -BaseParameterFilePath $resolvedParameterFilePath `
    -OverrideValues @{
        backendDisplayName = $backendDisplayName
        backendUniqueName = $backendUniqueName
        apiIdentifierUri = $backendIdentifierUri
    }

$outputs = $tenantDeployment.properties.outputs
$backendAppId = [string]$outputs.backendAppId.value
$backendServicePrincipalId = [string]$outputs.backendServicePrincipalId.value
$requiredAppRoleValue = [string]$outputs.backendRequiredAppRoleValue.value
$requiredAppRoleId = [string]$outputs.backendRequiredAppRoleId.value

Write-EnvFile -Path $backendEnvPath -Lines @(
    "TENANT_ID=$([string]$account.tenantId)",
    "BACKEND_CLIENT_ID=$backendAppId",
    "BACKEND_APP_ID_URI=$backendIdentifierUri",
    "REQUIRED_APP_ROLE=$requiredAppRoleValue",
    'CUSTOMER_REGISTRY_PATH=customer-registry.local.json'
)

Set-EntraConfigFile `
    -Path $entraConfigPath `
    -TenantId ([string]$account.tenantId) `
    -BackendDisplayName $backendDisplayName `
    -BackendAppId $backendAppId `
    -BackendServicePrincipalId $backendServicePrincipalId `
    -BackendIdentifierUri $backendIdentifierUri `
    -RequiredAppRoleValue $requiredAppRoleValue `
    -RequiredAppRoleId $requiredAppRoleId `
    -AssignmentRequired $true `
    -ResolvedKeyVaultName $KeyVaultName

[pscustomobject]@{
    tenantId = [string]$account.tenantId
    backend = [pscustomobject]@{
        displayName = $backendDisplayName
        appId = $backendAppId
        servicePrincipalId = $backendServicePrincipalId
        identifierUri = $backendIdentifierUri
        requiredAppRoleValue = $requiredAppRoleValue
        requiredAppRoleId = $requiredAppRoleId
        assignmentRequired = $true
    }
    files = [pscustomobject]@{
        entraConfig = $entraConfigPath
        backendEnv = $backendEnvPath
    }
} | ConvertTo-Json -Depth 8