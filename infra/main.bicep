targetScope = 'resourceGroup'

@description('Deployment location.')
param location string = resourceGroup().location

@description('Tags applied to created resources.')
param tags object = {}

@description('Azure Container Registry name.')
param containerRegistryName string

@description('Log Analytics workspace name.')
param logAnalyticsWorkspaceName string

@description('Container Apps managed environment name.')
param managedEnvironmentName string

@description('User-assigned managed identity name for the backend container app.')
param userAssignedIdentityName string

@description('Container App name for the backend API.')
param containerAppName string

@description('Existing Key Vault name used to store the Easy Auth client secret.')
param keyVaultName string

@description('Deploy the backend Container App resource. Set false for the initial infra-only pass.')
param deployBackendApp bool = true

@description('Full backend image reference in ACR.')
param backendImage string = ''

@description('Microsoft Entra tenant ID.')
param tenantId string

@description('Backend API client ID.')
param backendClientId string

@description('Backend API application ID URI.')
param backendAppIdUri string

@description('Required backend application role.')
param requiredAppRole string = 'Customer.Data.Read'

@description('Customer registry path inside the container image.')
param customerRegistryPath string = 'customer-registry.local.json'

@description('Easy Auth client ID.')
param easyAuthClientId string

@description('Easy Auth OpenID issuer URI.')
param easyAuthIssuer string = '${environment().authentication.loginEndpoint}${tenantId}/v2.0'

@description('Allowed audiences for Easy Auth token validation.')
param easyAuthAllowedAudiences array = []

@description('Allowed customer application IDs for Easy Auth token validation.')
param easyAuthAllowedClientApplications array = []

@description('Container App secret name used by Easy Auth.')
param easyAuthSecretName string = 'easyauthsecret'

@description('Key Vault secret URI used by the Container App for Easy Auth.')
@secure()
param easyAuthSecretKeyVaultUrl string = ''

@description('Requested backend CPU in cores, expressed as a string to preserve decimals.')
param backendCpu string = '0.5'

@description('Requested backend memory.')
param backendMemory string = '1Gi'

@description('Minimum backend replicas.')
param minReplicas int = 0

@description('Maximum backend replicas.')
param maxReplicas int = 2

var mergedTags = union({
  project: 'demo-app-reg'
  managedBy: 'bicep'
}, tags)

module containerRegistry './modules/container-registry.bicep' = {
  name: 'containerRegistry'
  params: {
    location: location
    name: containerRegistryName
    tags: mergedTags
  }
}

module containerEnvironment './modules/container-environment.bicep' = {
  name: 'containerEnvironment'
  params: {
    location: location
    environmentName: managedEnvironmentName
    workspaceName: logAnalyticsWorkspaceName
    tags: mergedTags
  }
}

module identity './modules/identity.bicep' = {
  name: 'backendIdentity'
  params: {
    location: location
    name: userAssignedIdentityName
    tags: mergedTags
  }
}

module backend './modules/container-app.bicep' = {
  name: 'backendContainerApp'
  params: {
    location: location
    tags: mergedTags
    appName: containerAppName
    managedEnvironmentId: containerEnvironment.outputs.id
    userAssignedIdentityId: identity.outputs.id
    userAssignedIdentityPrincipalId: identity.outputs.principalId
    acrName: containerRegistryName
    acrLoginServer: containerRegistry.outputs.loginServer
    keyVaultName: keyVaultName
    deployBackendApp: deployBackendApp
    backendImage: backendImage
    tenantId: tenantId
    backendClientId: backendClientId
    backendAppIdUri: backendAppIdUri
    requiredAppRole: requiredAppRole
    customerRegistryPath: customerRegistryPath
    easyAuthClientId: easyAuthClientId
    easyAuthIssuer: easyAuthIssuer
    easyAuthAllowedAudiences: easyAuthAllowedAudiences
    easyAuthAllowedClientApplications: easyAuthAllowedClientApplications
    easyAuthSecretName: easyAuthSecretName
    easyAuthSecretKeyVaultUrl: easyAuthSecretKeyVaultUrl
    backendCpu: backendCpu
    backendMemory: backendMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
  }
}

output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output managedEnvironmentName string = containerEnvironment.outputs.name
output managedEnvironmentId string = containerEnvironment.outputs.id
output userAssignedIdentityId string = identity.outputs.id
output userAssignedIdentityPrincipalId string = identity.outputs.principalId
output containerAppName string = backend.outputs.name
output containerAppFqdn string = backend.outputs.fqdn
output containerAppUrl string = backend.outputs.url
output containerAppCallbackUrl string = backend.outputs.callbackUrl
