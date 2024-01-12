metadata description = 'Creates an Azure Cognitive Services instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}
param principalId string = ''
param keyVaultName string
param identity object = {
  type: 'None'
}

param openAIKey string = 'AZURE-OPEN-AI-KEY'

var cognitiveServicesOpenAIUserDefinitionId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  identity: identity
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

resource openAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (principalId != '') {
  name: guid(subscription().id, resourceGroup().id, name, name, cognitiveServicesOpenAIUserDefinitionId, principalId)
  scope: account
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]


resource cosmosConnectionString 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: openAIKey
  properties: {
    value: account.listKeys().key1
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
