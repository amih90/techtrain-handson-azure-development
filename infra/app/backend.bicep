param name string
param location string = resourceGroup().location
param tags object = {}

param allowedOrigins array = []
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param keyVaultName string
param serviceName string = 'backend'
param storageAccountName string = ''

var abbrs = loadJsonContent('../abbreviations.json')

// Storage for Azure functions backend API
module storage '../core/storage/storage-account.bicep' = {
  name: 'storage-deployment'
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${replace(name, '-', '')}'
    location: location
    tags: tags
  }
}

module backend '../core/host/functions.bicep' = {
  name: '${serviceName}-functions-dotnet-module'
  dependsOn: [
    storage
  ]
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    allowedOrigins: allowedOrigins
    alwaysOn: true
    appSettings: appSettings
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    keyVaultName: keyVaultName
    runtimeName: 'dotnet'
    runtimeVersion: '6.0'
    storageAccountName: storage.outputs.name
    scmDoBuildDuringDeployment: false
  }
}

output SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID string = backend.outputs.identityPrincipalId
output SERVICE_BACKEND_NAME string = backend.outputs.name
output SERVICE_BACKEND_URI string = backend.outputs.uri
