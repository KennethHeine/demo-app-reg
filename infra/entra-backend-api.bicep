targetScope = 'tenant'

extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0'

@description('Backend API application display name.')
param backendDisplayName string = 'demo-app-reg-backend-api'

@description('Stable unique name for the backend application object.')
param backendUniqueName string = 'demo-app-reg-backend-api'

@description('Supported sign-in audience for the backend API.')
@allowed([
  'AzureADMyOrg'
  'AzureADMultipleOrgs'
  'AzureADandPersonalMicrosoftAccount'
  'PersonalMicrosoftAccount'
])
param signInAudience string = 'AzureADMyOrg'

@description('Application ID URI exposed by the backend API.')
param apiIdentifierUri string = 'api://kscloud.io/demo-app-reg-backend-api'

@description('Requested access token version for issued tokens.')
@allowed([
  1
  2
])
param requestedAccessTokenVersion int = 2

@description('Display name of the backend application role.')
param requiredAppRoleDisplayName string = 'Customer Data Reader'

@description('Description of the backend application role.')
param requiredAppRoleDescription string = 'Allows the customer application to read its own data from the demo backend.'

@description('Role claim value emitted by the backend API.')
param requiredAppRoleValue string = 'Customer.Data.Read'

@description('Stable identifier for the backend application role.')
param requiredAppRoleId string = guid(backendUniqueName, requiredAppRoleValue)

@description('Whether the backend enterprise application requires explicit assignment before token issuance.')
param appRoleAssignmentRequired bool = true

@description('Application tags used to identify the backend registration.')
param tags array = [
  'demo-app-reg'
  'backend-api'
  'bicep-managed'
]

resource backendApplication 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: backendUniqueName
  displayName: backendDisplayName
  signInAudience: signInAudience
  identifierUris: [
    apiIdentifierUri
  ]
  tags: tags
  api: {
    requestedAccessTokenVersion: requestedAccessTokenVersion
  }
  appRoles: [
    {
      allowedMemberTypes: [
        'Application'
      ]
      description: requiredAppRoleDescription
      displayName: requiredAppRoleDisplayName
      id: requiredAppRoleId
      isEnabled: true
      value: requiredAppRoleValue
    }
  ]
}

resource backendServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: backendApplication.appId
  displayName: backendDisplayName
  appRoleAssignmentRequired: appRoleAssignmentRequired
}

output backendAppId string = backendApplication.appId
output backendApplicationObjectId string = backendApplication.id
output backendDisplayName string = backendApplication.displayName
output backendIdentifierUri string = backendApplication.identifierUris[0]
output backendRequiredAppRoleId string = backendApplication.appRoles[0].id
output backendRequiredAppRoleValue string = backendApplication.appRoles[0].value
output backendServicePrincipalId string = backendServicePrincipal.id
