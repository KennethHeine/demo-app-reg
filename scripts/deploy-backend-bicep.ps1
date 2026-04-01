[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'demo-app-reg',
    [string]$Location = 'westeurope',
    [string]$ImageRepository = 'demo-app-reg-backend',
    [string]$ImageTag = (Get-Date -Format 'yyyyMMddHHmmss'),
    [switch]$SkipBuild,
    [switch]$RunRemoteE2E
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$entraConfigPath = Join-Path $root 'entra-config.local.json'
$backendEnvPath = Join-Path $root 'backend\.env'
$templateFilePath = Join-Path $root 'infra\main.bicep'
$parameterFilePath = Join-Path $root 'infra\main.parameters.json'
$dockerFilePath = Join-Path $root 'backend\Dockerfile'
$customerRegistryPath = Join-Path $root 'backend\customer-registry.local.json'
$easyAuthCredentialDisplayName = 'container-app-easyauth'
$easyAuthKeyVaultSecretName = 'backend-easyauth-client-secret'

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Required JSON file was not found: $Path"
    }

    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Read-KeyValueFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Required environment file was not found: $Path"
    }

    $values = @{}
    foreach ($line in Get-Content -Path $Path) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Count -eq 2) {
            $values[$parts[0].Trim()] = $parts[1].Trim()
        }
    }

    return $values
}

function Get-RequiredHashtableValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Table,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $value = [string]$Table[$Key]
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required value '$Key'."
    }

    return $value
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
        "demo-app-reg.$([System.Guid]::NewGuid().ToString('N')).parameters.json"
    )

    $parameterDocument | ConvertTo-Json -Depth 20 | Set-Content -Path $tempFilePath -Encoding UTF8
    return $tempFilePath
}

function Merge-Hashtables {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Base,
        [Parameter(Mandatory = $true)][hashtable]$Overrides
    )

    $merged = @{}
    foreach ($entry in $Base.GetEnumerator()) {
        $merged[$entry.Key] = $entry.Value
    }

    foreach ($entry in $Overrides.GetEnumerator()) {
        $merged[$entry.Key] = $entry.Value
    }

    return $merged
}

function Invoke-GroupDeployment {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$TemplateFilePath,
        [Parameter(Mandatory = $true)][string]$BaseParameterFilePath,
        [Parameter(Mandatory = $true)][hashtable]$OverrideValues
    )

    $tempParameterFilePath = New-DeploymentParametersFile -BaseParameterFilePath $BaseParameterFilePath -OverrideValues $OverrideValues

    try {
        $deploymentJson = az deployment group create `
            --name $Name `
            --resource-group $ResourceGroupName `
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

function Ensure-ResourceGroup {
    $resourceGroupJson = az group show --name $ResourceGroupName --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resourceGroupJson)) {
        return
    }

    az group create --name $ResourceGroupName --location $Location --output none | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create resource group '$ResourceGroupName'."
    }
}

function Ensure-EasyAuthClientSecret {
    param(
        [Parameter(Mandatory = $true)][string]$ApplicationId,
        [Parameter(Mandatory = $true)][string]$KeyVaultName,
        [Parameter(Mandatory = $true)][string]$KeyVaultSecretName,
        [Parameter(Mandatory = $true)][string]$CredentialDisplayName
    )

    $existingCredentialsJson = az ad app credential list --id $ApplicationId --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list credentials for app registration '$ApplicationId'."
    }

    $existingCredentials = $existingCredentialsJson | ConvertFrom-Json
    foreach ($credential in @($existingCredentials)) {
        if ($credential.displayName -eq $CredentialDisplayName) {
            az ad app credential delete --id $ApplicationId --key-id $credential.keyId --output none | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to delete the existing Easy Auth credential '$CredentialDisplayName'."
            }
        }
    }

    $newSecretValue = az ad app credential reset `
        --id $ApplicationId `
        --append `
        --display-name $CredentialDisplayName `
        --years 1 `
        --query password `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($newSecretValue)) {
        throw "Failed to create the Easy Auth client secret for app registration '$ApplicationId'."
    }

    az keyvault secret set --vault-name $KeyVaultName --name $KeyVaultSecretName --value $newSecretValue --output none | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to store the Easy Auth client secret in Key Vault '$KeyVaultName'."
    }

    return "https://$KeyVaultName.vault.azure.net/secrets/$KeyVaultSecretName"
}

function Ensure-AppRegistrationRedirectUri {
    param(
        [Parameter(Mandatory = $true)][string]$ApplicationId,
        [Parameter(Mandatory = $true)][string]$RedirectUri
    )

    $applicationJson = az ad app show --id $ApplicationId --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($applicationJson)) {
        throw "Failed to load app registration '$ApplicationId'."
    }

    $application = $applicationJson | ConvertFrom-Json
    $redirectUris = @()
    if ($null -ne $application.web -and $null -ne $application.web.redirectUris) {
        $redirectUris = @($application.web.redirectUris)
    }

    if ($redirectUris -notcontains $RedirectUri) {
        $redirectUris = @($redirectUris + $RedirectUri | Sort-Object -Unique)
        az ad app update --id $ApplicationId --enable-id-token-issuance true --web-redirect-uris $redirectUris --output none | Out-Null
    }
    else {
        az ad app update --id $ApplicationId --enable-id-token-issuance true --output none | Out-Null
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update redirect URIs for app registration '$ApplicationId'."
    }
}

$entraConfig = Read-JsonFile -Path $entraConfigPath
$backendEnv = Read-KeyValueFile -Path $backendEnvPath
$customerRegistry = Read-JsonFile -Path $customerRegistryPath

if (-not (Test-Path $dockerFilePath)) {
    throw "Backend Dockerfile was not found: $dockerFilePath"
}

Ensure-ResourceGroup

$tenantId = [string]$entraConfig.tenantId
$backendClientId = [string]$entraConfig.backend.appId
$backendAppIdUri = [string]$entraConfig.backend.identifierUri
$keyVaultName = [string]$entraConfig.keyVault.name
$requiredAppRole = Get-RequiredHashtableValue -Table $backendEnv -Key 'REQUIRED_APP_ROLE'
$customerAppIds = @($customerRegistry.customers | ForEach-Object { [string]$_.appId })
$allowedAudiences = @($backendClientId, $backendAppIdUri)
$deploymentStamp = Get-Date -Format 'yyyyMMddHHmmss'

$baseParameterDocument = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$containerRegistryName = [string]$baseParameterDocument.parameters.containerRegistryName.value
$containerAppName = [string]$baseParameterDocument.parameters.containerAppName.value

$commonOverrides = @{
    location = $Location
    keyVaultName = $keyVaultName
    tenantId = $tenantId
    backendClientId = $backendClientId
    backendAppIdUri = $backendAppIdUri
    requiredAppRole = $requiredAppRole
    easyAuthClientId = $backendClientId
    easyAuthAllowedAudiences = $allowedAudiences
    easyAuthAllowedClientApplications = $customerAppIds
}

$infraDeployment = Invoke-GroupDeployment `
    -Name "demo-app-reg-infra-$deploymentStamp" `
    -TemplateFilePath $templateFilePath `
    -BaseParameterFilePath $parameterFilePath `
    -OverrideValues (Merge-Hashtables -Base $commonOverrides -Overrides @{
        deployBackendApp = $false
        backendImage = ''
        easyAuthSecretKeyVaultUrl = ''
    })

$acrLoginServer = [string]$infraDeployment.properties.outputs.containerRegistryLoginServer.value
if ([string]::IsNullOrWhiteSpace($acrLoginServer)) {
    throw 'The infrastructure deployment did not return an ACR login server.'
}

if (-not $SkipBuild) {
    az acr build `
        --registry $containerRegistryName `
        --image "${ImageRepository}:$ImageTag" `
        --file $dockerFilePath `
        $root

    if ($LASTEXITCODE -ne 0) {
        throw 'The backend image build failed.'
    }
}

$easyAuthSecretKeyVaultUrl = Ensure-EasyAuthClientSecret `
    -ApplicationId $backendClientId `
    -KeyVaultName $keyVaultName `
    -KeyVaultSecretName $easyAuthKeyVaultSecretName `
    -CredentialDisplayName $easyAuthCredentialDisplayName

$backendImage = "$acrLoginServer/${ImageRepository}:$ImageTag"

$appDeployment = Invoke-GroupDeployment `
    -Name "demo-app-reg-app-$deploymentStamp" `
    -TemplateFilePath $templateFilePath `
    -BaseParameterFilePath $parameterFilePath `
    -OverrideValues (Merge-Hashtables -Base $commonOverrides -Overrides @{
        deployBackendApp = $true
        backendImage = $backendImage
        easyAuthSecretKeyVaultUrl = $easyAuthSecretKeyVaultUrl
    })

$containerAppUrl = [string]$appDeployment.properties.outputs.containerAppUrl.value
$callbackUrl = [string]$appDeployment.properties.outputs.containerAppCallbackUrl.value

if ([string]::IsNullOrWhiteSpace($containerAppUrl)) {
    throw 'The application deployment did not return a Container App URL.'
}

if ([string]::IsNullOrWhiteSpace($callbackUrl)) {
    throw 'The application deployment did not return a Container App Easy Auth callback URL.'
}

Ensure-AppRegistrationRedirectUri -ApplicationId $backendClientId -RedirectUri $callbackUrl

$remoteE2EResult = $null
if ($RunRemoteE2E) {
    $remoteE2EJson = & (Join-Path $root 'scripts\test-end-to-end.ps1') -ApiBaseUrl $containerAppUrl
    if ($LASTEXITCODE -ne 0) {
        throw 'Remote end-to-end verification failed.'
    }

    $remoteE2EResult = $remoteE2EJson | ConvertFrom-Json
}

[pscustomobject]@{
    resourceGroupName = $ResourceGroupName
    location = $Location
    containerRegistryName = $containerRegistryName
    containerAppName = $containerAppName
    containerAppUrl = $containerAppUrl
    easyAuthCallbackUrl = $callbackUrl
    keyVaultName = $keyVaultName
    image = $backendImage
    remoteE2E = $remoteE2EResult
} | ConvertTo-Json -Depth 10