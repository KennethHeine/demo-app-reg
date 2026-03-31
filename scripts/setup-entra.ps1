[CmdletBinding()]
param(
    [string]$Prefix = 'demo-app-reg',
    [string]$TenantId,
    [switch]$UseDeviceCode,
    [switch]$UseAzureCli,
    [string]$ApiDomain = 'kscloud.io',
    [string]$CustomerDefinitionsPath = 'customers.json',
    [string]$ResourceGroupName = 'demo-app-reg',
    [string]$KeyVaultName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$requiredRoleValue = 'Customer.Data.Read'
$localSecretDisplayName = 'local-demo-secret'
$localCertificateDisplayName = 'local-demo-certificate'
$script:GraphAccessToken = $null

function Get-JwtClaimValue {
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$ClaimName
    )

    $segments = $Token.Split('.')
    if ($segments.Count -lt 2) {
        throw 'The token did not contain a valid JWT payload.'
    }

    $payload = $segments[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
    }

    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
    $claims = $json | ConvertFrom-Json
    return $claims.$ClaimName
}

function Connect-GraphWithDeviceCode {
    param([Parameter(Mandatory = $true)][string]$Tenant)

    $clientId = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
    $scope = 'https://graph.microsoft.com/Application.ReadWrite.All https://graph.microsoft.com/AppRoleAssignment.ReadWrite.All https://graph.microsoft.com/Directory.ReadWrite.All offline_access openid profile'
    $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/devicecode" -ContentType 'application/x-www-form-urlencoded' -Body @{
        client_id = $clientId
        scope = $scope
    }

    Write-Host ''
    Write-Host $deviceCodeResponse.message
    Write-Host ''

    $tokenUri = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token"
    $attemptDelay = [int]$deviceCodeResponse.interval
    $deadline = (Get-Date).ToUniversalTime().AddSeconds([int]$deviceCodeResponse.expires_in)

    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        Start-Sleep -Seconds $attemptDelay

        $tokenResponse = Invoke-WebRequest -Method POST -Uri $tokenUri -ContentType 'application/x-www-form-urlencoded' -Body @{
            grant_type = 'urn:ietf:params:oauth:grant-type:device_code'
            client_id = $clientId
            device_code = $deviceCodeResponse.device_code
        } -SkipHttpErrorCheck

        if ($tokenResponse.StatusCode -eq 200) {
            $tokenPayload = $tokenResponse.Content | ConvertFrom-Json
            $script:GraphAccessToken = $tokenPayload.access_token
            return
        }

        $errorPayload = $tokenResponse.Content | ConvertFrom-Json
        switch ($errorPayload.error) {
            'authorization_pending' { continue }
            'slow_down' {
                $attemptDelay += 5
                continue
            }
            'authorization_declined' { throw 'Device code authentication was declined.' }
            'expired_token' { throw 'Device code authentication expired.' }
            default { throw "Device code authentication failed: $($tokenResponse.Content)" }
        }
    }

    throw 'Device code authentication expired.'
}

function Connect-GraphWithAzureCli {
    $accountJson = az account show --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
        throw 'Azure CLI is not logged in. Run az login or use another authentication mode.'
    }

    $account = $accountJson | ConvertFrom-Json
    $tokenJson = az account get-access-token --resource-type ms-graph --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tokenJson)) {
        throw 'Azure CLI could not acquire a Microsoft Graph access token.'
    }

    $tokenResponse = $tokenJson | ConvertFrom-Json
    $script:GraphAccessToken = $tokenResponse.accessToken
    return $account.tenantId
}

function Get-AzureCliAccount {
    $accountJson = az account show --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
        throw 'Azure CLI is not logged in. Run az login before provisioning Key Vault resources.'
    }

    return $accountJson | ConvertFrom-Json
}

function Invoke-GraphJson {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter()][object]$Body
    )

    if (-not [string]::IsNullOrWhiteSpace($script:GraphAccessToken)) {
        $headers = @{
            Authorization = "Bearer $($script:GraphAccessToken)"
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            $jsonBody = $Body | ConvertTo-Json -Depth 12 -Compress
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $headers -Body $jsonBody -ContentType 'application/json' -SkipHttpErrorCheck
        }
        else {
            $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $headers -SkipHttpErrorCheck
        }

        if ($response.StatusCode -ge 400) {
            throw "Graph request failed with status $($response.StatusCode): $($response.Content)"
        }

        if ([string]::IsNullOrWhiteSpace($response.Content)) {
            return $null
        }

        return $response.Content | ConvertFrom-Json -Depth 20
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $jsonBody = $Body | ConvertTo-Json -Depth 12 -Compress
        return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body $jsonBody -ContentType 'application/json' -OutputType PSObject
    }

    return Invoke-MgGraphRequest -Method $Method -Uri $Uri -OutputType PSObject
}

function Escape-ODataString {
    param([Parameter(Mandatory = $true)][string]$Value)
    return $Value.Replace("'", "''")
}

function Get-CollectionByFilter {
    param(
        [Parameter(Mandatory = $true)][string]$Resource,
        [Parameter(Mandatory = $true)][string]$Filter
    )

    $escapedFilter = [System.Uri]::EscapeDataString($Filter)
    $uri = "https://graph.microsoft.com/v1.0/${Resource}?`$filter=$escapedFilter"
    $response = Invoke-GraphJson -Method GET -Uri $uri
    if ($null -eq $response.value) {
        return @()
    }

    return @($response.value)
}

function Resolve-WorkspacePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $PathValue))
}

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-CustomerDefinitions {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Customer definitions file was not found: $Path"
    }

    $rawDefinitions = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $definitions = if ($null -ne $rawDefinitions.customers) {
        @($rawDefinitions.customers)
    }
    elseif ($rawDefinitions -is [System.Array]) {
        @($rawDefinitions)
    }
    else {
        throw "Customer definitions file must contain a 'customers' array: $Path"
    }

    if ($definitions.Count -eq 0) {
        throw "Customer definitions file does not contain any customers: $Path"
    }

    $seenCustomerIds = @{}
    foreach ($definition in $definitions) {
        $customerId = [string]$definition.customerId
        if ([string]::IsNullOrWhiteSpace($customerId)) {
            throw "Each customer definition must include a non-empty customerId."
        }

        if ($seenCustomerIds.ContainsKey($customerId)) {
            throw "Duplicate customerId '$customerId' found in $Path"
        }

        $seenCustomerIds[$customerId] = $true
    }

    return $definitions
}

function Get-DefaultKeyVaultName {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][string]$SubscriptionId
    )

    $safePrefix = ($Prefix -replace '[^a-zA-Z0-9]', '').ToLower()
    if ($safePrefix.Length -gt 12) {
        $safePrefix = $safePrefix.Substring(0, 12)
    }

    $safeSubscriptionId = ($SubscriptionId -replace '[^a-zA-Z0-9]', '').ToLower()
    $suffixLength = [Math]::Min(8, $safeSubscriptionId.Length)
    $suffix = $safeSubscriptionId.Substring(0, $suffixLength)
    $candidate = ($safePrefix + 'kv' + $suffix).ToLower()
    if ($candidate.Length -gt 24) {
        $candidate = $candidate.Substring(0, 24)
    }

    return $candidate
}

function Get-AzureSignedInUser {
    $userJson = az ad signed-in-user show --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($userJson)) {
        throw 'The Azure CLI login is not a user context that can be granted Key Vault access policies.'
    }

    return $userJson | ConvertFrom-Json
}

function Get-AzureResourceGroup {
    param([Parameter(Mandatory = $true)][string]$Name)

    $resourceGroupJson = az group show --name $Name --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resourceGroupJson)) {
        throw "Resource group '$Name' was not found."
    }

    return $resourceGroupJson | ConvertFrom-Json
}

function Ensure-KeyVault {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ResourceGroupName,
        [Parameter(Mandatory = $true)][string]$Location,
        [Parameter(Mandatory = $true)][string]$UserPrincipalName,
        [Parameter(Mandatory = $true)][string]$UserObjectId
    )

    $vaultJson = az keyvault show --name $Name --resource-group $ResourceGroupName --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vaultJson)) {
        $vaultJson = az keyvault create --name $Name --resource-group $ResourceGroupName --location $Location --output json
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vaultJson)) {
            throw "Failed to create Key Vault '$Name' in resource group '$ResourceGroupName'."
        }
    }

    $vault = $vaultJson | ConvertFrom-Json
    $rbacEnabled = [bool]$vault.properties.enableRbacAuthorization
    if ($rbacEnabled) {
        $roleAssignments = az role assignment list --assignee-object-id $UserObjectId --scope $vault.id --query "[?roleDefinitionName=='Key Vault Administrator']" --output json | ConvertFrom-Json
        if (@($roleAssignments).Count -eq 0) {
            az role assignment create --assignee-object-id $UserObjectId --assignee-principal-type User --role "Key Vault Administrator" --scope $vault.id --output none | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to assign Key Vault Administrator to $UserPrincipalName on vault '$Name'."
            }
        }
    }
    else {
        az keyvault set-policy --name $Name --upn $UserPrincipalName --secret-permissions get list set delete --certificate-permissions get list create import delete update --output none | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Key Vault access policy for $UserPrincipalName on vault '$Name'."
        }
    }

    return $vault
}

function Set-KeyVaultSecretValue {
    param(
        [Parameter(Mandatory = $true)][string]$VaultName,
        [Parameter(Mandatory = $true)][string]$SecretName,
        [Parameter(Mandatory = $true)][string]$SecretValue
    )

    az keyvault secret set --vault-name $VaultName --name $SecretName --value $SecretValue --output none | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to store secret '$SecretName' in Key Vault '$VaultName'."
    }
}

function Get-KeyVaultSecretBundle {
    param(
        [Parameter(Mandatory = $true)][string]$VaultName,
        [Parameter(Mandatory = $true)][string]$SecretName
    )

    $secretJson = az keyvault secret show --vault-name $VaultName --name $SecretName --output json
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($secretJson)) {
        throw "Failed to retrieve secret '$SecretName' from Key Vault '$VaultName'."
    }

    return $secretJson | ConvertFrom-Json
}

function Export-KeyVaultCertificateSecret {
    param(
        [Parameter(Mandatory = $true)][string]$VaultName,
        [Parameter(Mandatory = $true)][string]$CertificateName,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $secretBundle = Get-KeyVaultSecretBundle -VaultName $VaultName -SecretName $CertificateName
    $contentType = [string]$secretBundle.contentType
    $secretValue = [string]$secretBundle.value
    if ([string]::IsNullOrWhiteSpace($secretValue)) {
        throw "Certificate secret '$CertificateName' in Key Vault '$VaultName' did not contain a value."
    }

    $directoryPath = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    }

    if ($contentType -match 'pkcs12' -or $OutputPath.EndsWith('.pfx')) {
        [System.IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($secretValue))
    }
    else {
        Set-Content -Path $OutputPath -Value $secretValue -Encoding utf8
    }
}

function Reset-CertificateCredential {
    param(
        [Parameter(Mandatory = $true)][string]$AppId,
        [Parameter(Mandatory = $true)][string]$KeyVaultName,
        [Parameter(Mandatory = $true)][string]$CertificateName,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    az ad app credential reset --id $AppId --create-cert --cert $CertificateName --keyvault $KeyVaultName --display-name $DisplayName --output none | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create or assign certificate '$CertificateName' for application '$AppId'."
    }
}

function Get-VerifiedDomain {
    param([Parameter(Mandatory = $true)][string]$DomainName)

    $organization = Invoke-GraphJson -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains'
    $domains = @($organization.value[0].verifiedDomains)
    return $domains | Where-Object { $_.name -eq $DomainName } | Select-Object -First 1
}

function Get-UniqueItem {
    param(
        [AllowEmptyCollection()][object[]]$Items = @(),
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($Items.Count -gt 1) {
        throw "Found more than one $Description. Delete duplicates or pick a more specific prefix."
    }

    if ($Items.Count -eq 1) {
        return $Items[0]
    }

    return $null
}

function Get-OrCreateApplication {
    param([Parameter(Mandatory = $true)][string]$DisplayName)

    $existing = Get-UniqueItem -Items @(Get-CollectionByFilter -Resource 'applications' -Filter "displayName eq '$(Escape-ODataString $DisplayName)'") -Description "application named $DisplayName"
    if ($null -ne $existing) {
        return $existing
    }

    return Invoke-GraphJson -Method POST -Uri 'https://graph.microsoft.com/v1.0/applications' -Body @{
        displayName = $DisplayName
        signInAudience = 'AzureADMyOrg'
    }
}

function Get-OrCreateServicePrincipal {
    param([Parameter(Mandatory = $true)][string]$AppId)

    $existing = Get-UniqueItem -Items @(Get-CollectionByFilter -Resource 'servicePrincipals' -Filter "appId eq '$AppId'") -Description "service principal for appId $AppId"
    if ($null -ne $existing) {
        return $existing
    }

    return Invoke-GraphJson -Method POST -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Body @{
        appId = $AppId
    }
}

function Convert-ToWritableAppRole {
    param([Parameter(Mandatory = $true)][object]$Role)

    return @{
        allowedMemberTypes = @($Role.allowedMemberTypes)
        description = $Role.description
        displayName = $Role.displayName
        id = $Role.id
        isEnabled = [bool]$Role.isEnabled
        value = $Role.value
    }
}

function Convert-ToWritableRequiredResourceAccess {
    param([Parameter(Mandatory = $true)][object]$Entry)

    return @{
        resourceAppId = $Entry.resourceAppId
        resourceAccess = @(
            @($Entry.resourceAccess | ForEach-Object {
                @{
                    id = $_.id
                    type = $_.type
                }
            })
        )
    }
}

function Update-BackendApplication {
    param(
        [Parameter(Mandatory = $true)][object]$Application,
        [Parameter(Mandatory = $true)][string]$IdentifierUri
    )

    $existingRoles = @($Application.appRoles)
    $matchingRole = $existingRoles | Where-Object { $_.value -eq $requiredRoleValue } | Select-Object -First 1
    if ($null -eq $matchingRole) {
        $matchingRole = @{
            allowedMemberTypes = @('Application')
            description = 'Allows the customer application to read its own data from the demo backend.'
            displayName = 'Customer Data Reader'
            id = [guid]::NewGuid().Guid
            isEnabled = $true
            value = $requiredRoleValue
        }
    }
    else {
        $matchingRole = Convert-ToWritableAppRole -Role $matchingRole
    }

    $otherRoles = @($existingRoles | Where-Object { $_.value -ne $requiredRoleValue } | ForEach-Object {
        Convert-ToWritableAppRole -Role $_
    })

    $updateBody = @{
        identifierUris = @($IdentifierUri)
        appRoles = @($otherRoles + $matchingRole)
        api = @{
            requestedAccessTokenVersion = 2
        }
    }

    Invoke-GraphJson -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)" -Body $updateBody | Out-Null
    return Invoke-GraphJson -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)"
}

function Update-RequiredResourceAccess {
    param(
        [Parameter(Mandatory = $true)][object]$Application,
        [Parameter(Mandatory = $true)][string]$ResourceAppId,
        [Parameter(Mandatory = $true)][string]$RoleId
    )

    $otherEntries = @($Application.requiredResourceAccess | Where-Object { $_.resourceAppId -ne $ResourceAppId } | ForEach-Object {
        Convert-ToWritableRequiredResourceAccess -Entry $_
    })

    $newEntry = @{
        resourceAppId = $ResourceAppId
        resourceAccess = @(
            @{
                id = $RoleId
                type = 'Role'
            }
        )
    }

    Invoke-GraphJson -Method PATCH -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)" -Body @{
        requiredResourceAccess = @($otherEntries + $newEntry)
    } | Out-Null

    return Invoke-GraphJson -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)"
}

function Add-ClientSecret {
    param(
        [Parameter(Mandatory = $true)][object]$Application,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    $password = Invoke-GraphJson -Method POST -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)/addPassword" -Body @{
        passwordCredential = @{
            displayName = $DisplayName
            endDateTime = (Get-Date).ToUniversalTime().AddYears(1).ToString('o')
        }
    }

    return $password.secretText
}

function Replace-ClientSecret {
    param(
        [Parameter(Mandatory = $true)][object]$Application,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    $existingCredentials = @($Application.passwordCredentials | Where-Object { $_.displayName -eq $DisplayName })
    foreach ($existingCredential in $existingCredentials) {
        Invoke-GraphJson -Method POST -Uri "https://graph.microsoft.com/v1.0/applications/$($Application.id)/removePassword" -Body @{
            keyId = $existingCredential.keyId
        } | Out-Null
    }

    return Add-ClientSecret -Application $Application -DisplayName $DisplayName
}

function Ensure-AppRoleAssignment {
    param(
        [Parameter(Mandatory = $true)][object]$PrincipalServicePrincipal,
        [Parameter(Mandatory = $true)][object]$ResourceServicePrincipal,
        [Parameter(Mandatory = $true)][string]$RoleId
    )

    $existingAssignmentsResponse = Invoke-GraphJson -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($PrincipalServicePrincipal.id)/appRoleAssignments"
    $existingAssignments = @($existingAssignmentsResponse.value)
    $match = $existingAssignments | Where-Object {
        [string]$_.resourceId -eq [string]$ResourceServicePrincipal.id -and [string]$_.appRoleId -eq [string]$RoleId
    } | Select-Object -First 1

    if ($null -ne $match) {
        return
    }

    Invoke-GraphJson -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($PrincipalServicePrincipal.id)/appRoleAssignments" -Body @{
        principalId = $PrincipalServicePrincipal.id
        resourceId = $ResourceServicePrincipal.id
        appRoleId = $RoleId
    } | Out-Null
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

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    return [System.IO.Path]::GetRelativePath($BasePath, $TargetPath)
}

if ($UseAzureCli) {
    $resolvedTenantId = Connect-GraphWithAzureCli
    $effectiveTenantId = if ([string]::IsNullOrWhiteSpace($TenantId)) { $resolvedTenantId } else { $TenantId }
}
elseif ($UseDeviceCode) {
    $tenantForAuthentication = if ([string]::IsNullOrWhiteSpace($TenantId)) { 'organizations' } else { $TenantId }
    Connect-GraphWithDeviceCode -Tenant $tenantForAuthentication
    $effectiveTenantId = if ([string]::IsNullOrWhiteSpace($TenantId)) {
        [string](Get-JwtClaimValue -Token $script:GraphAccessToken -ClaimName 'tid')
    }
    else {
        $TenantId
    }
}
else {
    Import-Module Microsoft.Graph.Authentication
    $graphContext = Get-MgContext
    if ($null -eq $graphContext) {
        throw 'No Microsoft Graph session found. Run Connect-MgGraph with Application.ReadWrite.All, AppRoleAssignment.ReadWrite.All, and Directory.ReadWrite.All, or rerun this script with -UseDeviceCode.'
    }

    $effectiveTenantId = if ([string]::IsNullOrWhiteSpace($TenantId)) { $graphContext.TenantId } else { $TenantId }
}

$azureCliAccount = Get-AzureCliAccount
$azureResourceGroup = Get-AzureResourceGroup -Name $ResourceGroupName
$azureSignedInUser = Get-AzureSignedInUser
$resolvedKeyVaultName = if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    Get-DefaultKeyVaultName -Prefix $Prefix -SubscriptionId ([string]$azureCliAccount.id)
}
else {
    $KeyVaultName.ToLowerInvariant()
}

$keyVault = Ensure-KeyVault -Name $resolvedKeyVaultName -ResourceGroupName $ResourceGroupName -Location ([string]$azureResourceGroup.location) -UserPrincipalName ([string]$azureSignedInUser.userPrincipalName) -UserObjectId ([string]$azureSignedInUser.id)
$keyVaultUrl = [string]$keyVault.properties.vaultUri

$backendDisplayName = "$Prefix-backend-api"
$resolvedCustomerDefinitionsPath = Resolve-WorkspacePath -Root $root -PathValue $CustomerDefinitionsPath
$customerDefinitions = Get-CustomerDefinitions -Path $resolvedCustomerDefinitionsPath
$verifiedDomain = Get-VerifiedDomain -DomainName $ApiDomain
if ($null -eq $verifiedDomain) {
    throw "The domain '$ApiDomain' is not present in the tenant verified domains."
}

$apiIdentifierUri = "api://$ApiDomain/$backendDisplayName"

$backendApplication = Update-BackendApplication -Application (Get-OrCreateApplication -DisplayName $backendDisplayName) -IdentifierUri $apiIdentifierUri
$backendRole = @($backendApplication.appRoles | Where-Object { $_.value -eq $requiredRoleValue } | Select-Object -First 1)
$backendServicePrincipal = Get-OrCreateServicePrincipal -AppId $backendApplication.appId

$apiScope = "$apiIdentifierUri/.default"

$provisionedCustomers = @()
foreach ($customerDefinition in $customerDefinitions) {
    $customerId = [string]$customerDefinition.customerId
    $customerDisplayName = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'displayName')
    if ([string]::IsNullOrWhiteSpace($customerDisplayName)) {
        $customerDisplayName = "$Prefix-$customerId"
    }

    $customerAuthMethod = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'authMethod')
    if ([string]::IsNullOrWhiteSpace($customerAuthMethod)) {
        $customerAuthMethod = 'client-secret'
    }

    $secretName = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'keyVaultSecretName')
    if ([string]::IsNullOrWhiteSpace($secretName)) {
        $secretName = "$customerId-client-secret"
    }

    $certificateName = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'keyVaultCertificateName')
    if ([string]::IsNullOrWhiteSpace($certificateName)) {
        $certificateName = "$customerId-client-certificate"
    }

    $customerApplication = Update-RequiredResourceAccess -Application (Get-OrCreateApplication -DisplayName $customerDisplayName) -ResourceAppId $backendApplication.appId -RoleId $backendRole.id
    $customerServicePrincipal = Get-OrCreateServicePrincipal -AppId $customerApplication.appId

    Ensure-AppRoleAssignment -PrincipalServicePrincipal $customerServicePrincipal -ResourceServicePrincipal $backendServicePrincipal -RoleId $backendRole.id
    $configuredEnvFilePath = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'envFilePath')
    $resolvedEnvFilePath = if (-not [string]::IsNullOrWhiteSpace($configuredEnvFilePath)) {
        Resolve-WorkspacePath -Root $root -PathValue $configuredEnvFilePath
    }
    else {
        $null
    }
    $apiBaseUrl = [string](Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'apiBaseUrl')
    if ([string]::IsNullOrWhiteSpace($apiBaseUrl)) {
        $apiBaseUrl = 'http://127.0.0.1:8000'
    }
    $resolvedCertificateOutputPath = $null

    $envLines = @(
        "TENANT_ID=$effectiveTenantId",
        "CLIENT_ID=$($customerApplication.appId)",
        "API_SCOPE=$apiScope",
        "API_BASE_URL=$apiBaseUrl",
        "EXPECTED_CUSTOMER_ID=$customerId"
    )

    switch ($customerAuthMethod.ToLowerInvariant()) {
        'client-secret' {
            $customerSecret = Replace-ClientSecret -Application $customerApplication -DisplayName $localSecretDisplayName
            Set-KeyVaultSecretValue -VaultName $resolvedKeyVaultName -SecretName $secretName -SecretValue $customerSecret
            $envLines += @(
                'CLIENT_AUTH_MODE=secret',
                "CLIENT_SECRET=$customerSecret"
            )
        }
        'certificate' {
            Reset-CertificateCredential -AppId $customerApplication.appId -KeyVaultName $resolvedKeyVaultName -CertificateName $certificateName -DisplayName $localCertificateDisplayName
            $configuredCertificatePath = Get-OptionalPropertyValue -InputObject $customerDefinition -PropertyName 'localCertificatePath'
            $configuredCertificatePathText = [string]$configuredCertificatePath

            if ([string]::IsNullOrWhiteSpace($configuredCertificatePathText)) {
                if ($null -ne $resolvedEnvFilePath) {
                    $configuredCertificatePathText = Join-Path -Path (Split-Path -Parent $resolvedEnvFilePath) -ChildPath "$certificateName.pfx"
                }
                else {
                    $configuredCertificatePathText = Join-Path -Path $root -ChildPath "$certificateName.pfx"
                }
            }

            $resolvedCertificateOutputPath = Resolve-WorkspacePath -Root $root -PathValue $configuredCertificatePathText
            Export-KeyVaultCertificateSecret -VaultName $resolvedKeyVaultName -CertificateName $certificateName -OutputPath $resolvedCertificateOutputPath

            $certificatePathForEnv = $resolvedCertificateOutputPath
            if ($null -ne $resolvedEnvFilePath) {
                $certificatePathForEnv = Get-RelativePathSafe -BasePath (Split-Path -Parent $resolvedEnvFilePath) -TargetPath $resolvedCertificateOutputPath
            }

            $envLines += @(
                'CLIENT_AUTH_MODE=certificate',
                "CLIENT_CERTIFICATE_PATH=$certificatePathForEnv"
            )
        }
        default {
            throw "Unsupported authMethod '$customerAuthMethod' for customer '$customerId'."
        }
    }

    if ($null -ne $resolvedEnvFilePath) {
        Write-EnvFile -Path $resolvedEnvFilePath -Lines $envLines
    }

    $provisionedCustomers += [pscustomobject]@{
        customerId = $customerId
        displayName = $customerDisplayName
        appId = $customerApplication.appId
        servicePrincipalId = $customerServicePrincipal.id
        envFilePath = $resolvedEnvFilePath
        authMethod = $customerAuthMethod
        keyVaultSecretName = if ($customerAuthMethod -eq 'client-secret') { $secretName } else { $null }
        keyVaultCertificateName = if ($customerAuthMethod -eq 'certificate') { $certificateName } else { $null }
    }
}

$customerRegistryPath = Join-Path $root 'backend\customer-registry.local.json'
$customerRegistry = [pscustomobject]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    customers = @($provisionedCustomers | ForEach-Object {
        [pscustomobject]@{
            customerId = $_.customerId
            appId = $_.appId
            displayName = $_.displayName
        }
    })
}

$customerRegistry | ConvertTo-Json -Depth 6 | Set-Content -Path $customerRegistryPath -Encoding utf8

Write-EnvFile -Path (Join-Path $root 'backend\.env') -Lines @(
    "TENANT_ID=$effectiveTenantId",
    "BACKEND_CLIENT_ID=$($backendApplication.appId)",
    "BACKEND_APP_ID_URI=$apiIdentifierUri",
    "REQUIRED_APP_ROLE=$requiredRoleValue",
    "CUSTOMER_REGISTRY_PATH=customer-registry.local.json"
)

$summary = [pscustomobject]@{
    tenantId = $effectiveTenantId
    apiScope = $apiScope
    customerDefinitionsPath = $resolvedCustomerDefinitionsPath
    keyVault = [pscustomobject]@{
        name = $resolvedKeyVaultName
        resourceGroupName = $ResourceGroupName
        vaultUri = $keyVaultUrl
    }
    backend = [pscustomobject]@{
        displayName = $backendDisplayName
        appId = $backendApplication.appId
        servicePrincipalId = $backendServicePrincipal.id
        identifierUri = $apiIdentifierUri
    }
    customers = @($provisionedCustomers | ForEach-Object {
        [pscustomobject]@{
            customerId = $_.customerId
            displayName = $_.displayName
            appId = $_.appId
            servicePrincipalId = $_.servicePrincipalId
            authMethod = $_.authMethod
        }
    })
    customerRegistryPath = $customerRegistryPath
    envFiles = [pscustomobject]@{
        backend = (Join-Path $root 'backend\.env')
        customers = @($provisionedCustomers | Where-Object { -not [string]::IsNullOrWhiteSpace($_.envFilePath) } | ForEach-Object {
            [pscustomobject]@{
                customerId = $_.customerId
                path = $_.envFilePath
            }
        })
    }
}

$summaryPath = Join-Path $root 'entra-config.local.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding utf8
$summary | ConvertTo-Json -Depth 8
