param location string
param tags object = {}
param appName string
param managedEnvironmentId string
param userAssignedIdentityId string
param userAssignedIdentityPrincipalId string
param acrName string
param acrLoginServer string
param keyVaultName string
param deployBackendApp bool = true
param backendImage string = ''
param tenantId string
param backendClientId string
param backendAppIdUri string
param requiredAppRole string = 'Customer.Data.Read'
param customerRegistryPath string = 'customer-registry.local.json'
param easyAuthClientId string
param easyAuthIssuer string
param easyAuthAllowedAudiences array = []
param easyAuthAllowedClientApplications array = []
param easyAuthSecretName string = 'easyauthsecret'
@secure()
param easyAuthSecretKeyVaultUrl string = ''
param backendCpu string = '0.5'
param backendMemory string = '1Gi'
param minReplicas int = 0
param maxReplicas int = 2

var userAssignedIdentities = {
  '${userAssignedIdentityId}': {}
}

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var keyVaultSecretsUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

var aadValidation = empty(easyAuthAllowedClientApplications)
  ? {
      allowedAudiences: easyAuthAllowedAudiences
    }
  : {
      allowedAudiences: easyAuthAllowedAudiences
      jwtClaimChecks: {
        allowedClientApplications: easyAuthAllowedClientApplications
      }
    }

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, userAssignedIdentityPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, userAssignedIdentityPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinitionId
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-10-02-preview' = if (deployBackendApp) {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: userAssignedIdentities
  }
  properties: {
    environmentId: managedEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        allowInsecure: false
        external: true
        targetPort: 8080
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: acrLoginServer
          identity: userAssignedIdentityId
        }
      ]
      secrets: empty(easyAuthSecretKeyVaultUrl)
        ? []
        : [
            {
              name: easyAuthSecretName
              keyVaultUrl: easyAuthSecretKeyVaultUrl
              identity: userAssignedIdentityId
            }
          ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: backendImage
          env: [
            {
              name: 'TENANT_ID'
              value: tenantId
            }
            {
              name: 'BACKEND_CLIENT_ID'
              value: backendClientId
            }
            {
              name: 'BACKEND_APP_ID_URI'
              value: backendAppIdUri
            }
            {
              name: 'REQUIRED_APP_ROLE'
              value: requiredAppRole
            }
            {
              name: 'CUSTOMER_REGISTRY_PATH'
              value: customerRegistryPath
            }
          ]
          probes: [
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 6
              timeoutSeconds: 5
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 20
              periodSeconds: 20
              failureThreshold: 3
              timeoutSeconds: 5
            }
          ]
          resources: {
            cpu: json(backendCpu)
            memory: backendMemory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
  dependsOn: [
    acrPullAssignment
    keyVaultSecretsUserAssignment
  ]
}

resource authConfig 'Microsoft.App/containerApps/authConfigs@2025-10-02-preview' = if (deployBackendApp && !empty(easyAuthSecretKeyVaultUrl)) {
  parent: containerApp
  name: 'current'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'Return401'
      excludedPaths: [
        '/health'
      ]
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: easyAuthClientId
          clientSecretSettingName: easyAuthSecretName
          openIdIssuer: easyAuthIssuer
        }
        validation: aadValidation
      }
    }
  }
}

output name string = deployBackendApp ? containerApp.name : appName
output fqdn string = deployBackendApp ? containerApp!.properties.configuration.ingress.fqdn : ''
output url string = deployBackendApp ? 'https://${containerApp!.properties.configuration.ingress.fqdn}' : ''
output callbackUrl string = deployBackendApp ? 'https://${containerApp!.properties.configuration.ingress.fqdn}/.auth/login/aad/callback' : ''
