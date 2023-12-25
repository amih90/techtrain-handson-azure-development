targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param apiServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param cosmosAccountName string = ''
param cosmosDatabaseName string = ''
param keyVaultName string = ''
param logAnalyticsName string = ''
param webServiceName string = ''
param apimServiceName string = ''
param managedIdentityName string = ''
param eventHubNamespaceName string = ''

@description('Flag to use Azure API Management to mediate the calls between the Web frontend and the backend API')
param useAPIM bool = false

@description('Flag to enable data streaming')
param enableDataStreaming bool = false

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// The application frontend
module web './app/web.bicep' = {
  name: 'web'
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
  params: {
    name: web.outputs.SERVICE_WEB_NAME
    appSettings: {
      REACT_APP_API_BASE_URL: useAPIM ? apimApi.outputs.SERVICE_API_URI : api.outputs.SERVICE_API_URI
      REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
      WEBSITE_RUN_FROM_PACKAGE: 1
    }
  }
}

// The application backend
module api './app/api.bicep' = {
  name: 'api'
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    allowedOrigins: [ web.outputs.SERVICE_WEB_URI ]
    appSettings: {
      WEBSITE_RUN_FROM_PACKAGE: 1
      AZURE_COSMOS_CONNECTION_STRING_KEY: cosmos.outputs.connectionStringKey
      AZURE_COSMOS_DATABASE_NAME: cosmos.outputs.databaseName
      AZURE_COSMOS_ENDPOINT: cosmos.outputs.endpoint
      API_ALLOW_ORIGINS: web.outputs.SERVICE_WEB_URI
    }
  }
}

// Give the API access to KeyVault
module apiKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
  }
}

// Give the API the role to access Cosmos
module apiCosmosSqlRoleAssign './core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = {
  name: 'api-cosmos-access'
  params: {
    accountName: cosmos.outputs.accountName
    roleDefinitionId: cosmos.outputs.roleDefinitionId
    principalId: api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID
  }
}

// Give the API the role to access Cosmos
module userComsosSqlRoleAssign './core/database/cosmos/sql/cosmos-sql-role-assign.bicep' = if (principalId != '') {
  name: 'user-cosmos-access'
  params: {
    accountName: cosmos.outputs.accountName
    roleDefinitionId: cosmos.outputs.roleDefinitionId
    principalId: principalId
  }
}

// The application database
module cosmos './app/db.bicep' = {
  name: 'cosmos'
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
  params: {
    location: location
    name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
  }
}

module eventHubRequests './core/messaging/eventhub.bicep' = if (enableDataStreaming) {
  name: 'eventhub-requests-deployment'
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

// Configures the API in the Azure API Management (APIM) service
module apimApi './app/apim-api.bicep' = if (useAPIM) {
  name: 'apim-api-deployment'
  params: {
    name: useAPIM ? apim.outputs.apimServiceName : ''
    apiName: 'todo-api'
    apiDisplayName: 'Simple Todo API'
    apiDescription: 'This is a simple Todo API'
    apiPath: 'todo'
    webFrontendUrl: web.outputs.SERVICE_WEB_URI
    apiBackendUrl: api.outputs.SERVICE_API_URI
    apiAppName: api.outputs.SERVICE_API_NAME
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
output USE_APIM bool = useAPIM
output ENABLE_DATA_STREAMING bool = enableDataStreaming
output EVENTHUB_CONNECTION_CONNECTION_STRING string =  eventHubRequests.outputs.eventHubConnectionString
output SERVICE_API_ENDPOINTS array = useAPIM ? [ apimApi.outputs.SERVICE_API_URI, api.outputs.SERVICE_API_URI ]: []
