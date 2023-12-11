targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param apiServiceName string = ''
param backendServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param cosmosAccountName string = ''
param cosmosDatabaseName string = ''
param keyVaultName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param webServiceName string = ''
param apimServiceName string = ''
param managedIdentityName string = ''
param eventHubNamespaceName string = ''
param adxClusterName string = ''

@description('Flag to use Azure API Management to mediate the calls between the Web frontend and the backend API')
param useAPIM bool = false

@description('Flag to enable data streaming')
param enableDataStreaming bool = false

@description('Flag to use Azure Data Explorer')
param useADX bool = false

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application frontend
module web './app/web.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
  }
}

module webAppSettings './core/host/appservice-appsettings.bicep' = {
  name: 'web-appsettings'
  scope: rg
  params: {
    name: web.outputs.SERVICE_WEB_NAME
    appSettings: {
      REACT_APP_API_BASE_URL: useAPIM ? apimApi.outputs.SERVICE_API_URI : api.outputs.SERVICE_API_URI
      REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
    }
  }
}

// The application backend
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    allowedOrigins: [ web.outputs.SERVICE_WEB_URI ]
    appSettings: {
      AZURE_COSMOS_CONNECTION_STRING_KEY: cosmos.outputs.connectionStringKey
      AZURE_COSMOS_DATABASE_NAME: cosmos.outputs.databaseName
      AZURE_COSMOS_ENDPOINT: cosmos.outputs.endpoint
      API_ALLOW_ORIGINS: web.outputs.SERVICE_WEB_URI
    }
  }
}


// The backend application based on functions
module backend './app/backend.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesFunctions}be-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    allowedOrigins: [ web.outputs.SERVICE_WEB_URI ]
    appSettings: {
    }
  }
}

// Give the API access to KeyVault
module apiKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
  }
}

// Give the API the role to access Cosmos
module apiCosmosSqlRoleAssign './core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = {
  name: 'api-cosmos-access'
  scope: rg
  params: {
    accountName: cosmos.outputs.accountName
    roleDefinitionId: cosmos.outputs.roleDefinitionId
    principalId: api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
  }
}

// Give the API the role to access Cosmos
module userComsosSqlRoleAssign './core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = if (principalId != '') {
  name: 'user-cosmos-access'
  scope: rg
  params: {
    accountName: cosmos.outputs.accountName
    roleDefinitionId: cosmos.outputs.roleDefinitionId
    principalId: principalId
  }
}

// The application database
module cosmos './app/db.bicep' = {
  name: 'cosmos'
  scope: rg
  params: {
    accountName: !empty(cosmosAccountName) ? cosmosAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    databaseName: cosmosDatabaseName
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.name
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
    }
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Creates Azure API Management (APIM) service to mediate the requests between the frontend and the backend API
module apim './core/gateway/apim.bicep' = if (useAPIM) {
  name: 'apim-deployment'
  scope: rg
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
  }
}

// Configure a user managed identity
module userManagedIdentity './core/security/user-managed-identity.bicep' = {
  name: 'msi-deployment'
  scope: rg
  params: {
    location: location
    name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
  }
}

// Configure an Event Hub
module eventHubRequests './core/messaging/eventhub.bicep' = if (enableDataStreaming) {
  name: 'eventhub-requests-deployment'
  scope: rg
  params: {
    location: location
    workspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    eventHubNamespaceName: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    eventHubName: '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
    roleAssignments: [
      {
        principalType: 'ServicePrincipal'
        roleDefinitionId: 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde' // Azure Event Hubs Data Receiver
        principalId: userManagedIdentity.outputs.properties.principalId
      }
    ]
  }
}

// Configure Azure Data Explorer
module adx './core/database/adx/adx.bicep' = if (useADX) {
  name: 'adx-deployment'
  scope: rg
  params: {
    clusterName: !empty(adxClusterName) ? adxClusterName : '${abbrs.kustoClusters}${resourceToken}'
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${userManagedIdentity.outputs.resourceId}': {}
      }
    }
    databases: [
      {
        name: 'RawEvents'
        properties: {
          hotCachePeriod: 'P1D'
          softDeletePeriod: 'P30D'
        }
        scriptsContent: [
          loadTextContent('app/resources/requests.csl')
        ]
      }
    ]
  }
}

module eventHubAdxDataConnection './core/database/adx/adx-data-connection.bicep' = if (enableDataStreaming && useADX) {
  name: 'dc-eventhub-adx-requests-deployment'
  scope: rg
  dependsOn: [
    adx
  ]
  params: {
    clusterName: adx.outputs.clusterName
    clusterLocation: location
    databaseName: 'RawEvents'
    name: 'dc-eventhub-adx-requests'
    properties: {
      compression: 'None'
      consumerGroup: '$Default'
      databaseRouting: 'Single'
      dataFormat: 'MULTIJSON'
      eventSystemProperties: []
      eventHubResourceId: eventHubRequests.outputs.eventHubResourceId
      managedIdentityResourceId: userManagedIdentity.outputs.resourceId
      mappingRuleName: 'RequestsJsonMapping'
      tableName: 'Requests'
    }
  }
}

// Configures the API in the Azure API Management (APIM) service
module apimApi './app/apim-api.bicep' = if (useAPIM) {
  name: 'apim-api-deployment'
  scope: rg
  params: {
    name: useAPIM ? apim.outputs.apimServiceName : ''
    apiName: 'todo-api'
    apiDisplayName: 'Simple Todo API'
    apiDescription: 'This is a simple Todo API'
    apiPath: 'todo'
    webFrontendUrl: web.outputs.SERVICE_WEB_URI
    apiBackendUrl: api.outputs.SERVICE_API_URI
    apiAppName: api.outputs.SERVICE_API_NAME
    eventhubConnectionString: eventHubRequests.outputs.eventHubConnectionString
  }
}

// Data outputs
output AZURE_COSMOS_ENDPOINT string = cosmos.outputs.endpoint
output AZURE_COSMOS_CONNECTION_STRING_KEY string = cosmos.outputs.connectionStringKey
output AZURE_COSMOS_DATABASE_NAME string = cosmos.outputs.databaseName

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output REACT_APP_API_BASE_URL string = useAPIM ? apimApi.outputs.SERVICE_API_URI : api.outputs.SERVICE_API_URI
output REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output REACT_APP_WEB_BASE_URL string = web.outputs.SERVICE_WEB_URI
output BACKEND_API_ENDPOINT string = backend.outputs.SERVICE_BACKEND_URI
output USE_APIM bool = useAPIM
output ENABLE_DATA_STREAMING bool = enableDataStreaming
output EVENTHUB_CONNECTION_CONNECTION_STRING string =  eventHubRequests.outputs.eventHubConnectionString
output SERVICE_API_ENDPOINTS array = useAPIM ? [ apimApi.outputs.SERVICE_API_URI, api.outputs.SERVICE_API_URI ]: []
