@minLength(1)
@description('Primary location for all resources')
param location string

@description('Event Hub Namespace name')
param eventHubNamespaceName string

@description('Event Hub name')
param eventHubName string

@allowed([
  'Basic', 'Premium', 'Standard'
])
@description('Event Hub Namespace SKU')
param eventHubNamespaceSkuName string = 'Standard'

@description('Event Hub Namespace capacity')
param eventHubNamespaceSkuCapacity int = 1

@description('Event Hub Namespace zone redundant')
param eventHubNamespaceZoneRedundant bool = true

@minValue(1)
@maxValue(7)
@description('Event Hub message retention in days')
param eventHubMessageRetentionInDays int = 7

@minValue(1)
@maxValue(32)
@description('Event Hub partition count')
param eventHubPartitionCount int = 1

@description('Event Hub consumer group names')
param eventHubConsumerGroupNames array = []

@description('The log analytics workspace id used for logging & monitoring')
param workspaceId string = ''

@description('Role assignments to be created on the event hub scope')
param roleAssignments array = []


resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubNamespaceSkuName
    tier: eventHubNamespaceSkuName
    capacity: eventHubNamespaceSkuCapacity
  }
  properties: {
    zoneRedundant: eventHubNamespaceZoneRedundant
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: eventHubMessageRetentionInDays
    partitionCount: eventHubPartitionCount
  }
}

resource eventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for assignment in roleAssignments: {
  name: guid(subscription().id, resourceGroup().id, eventHubNamespaceName, eventHubName, assignment.roleDefinitionId, assignment.principalId)
  scope: eventHub
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', assignment.roleDefinitionId)
    principalId: assignment.principalId
    principalType: assignment.principalType
  }
}]

resource consumerGroups 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01-preview' = [for consumerGroupName in eventHubConsumerGroupNames: {
  parent: eventHub
  name: consumerGroupName.Name
  properties: {
    userMetadata: consumerGroupName.userMetadata
  }
}]

// Grant Listen and Send on our event hub
resource eventHubNamespaceNameEventHubNameListenSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

// Monitoring
resource evhnsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'evhns-diagnostics'
  scope: eventHubNamespace
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

var eventHubConnectionStringListenSend = eventHubNamespaceNameEventHubNameListenSend.listKeys().primaryConnectionString

output eventHubNamespaceName string = eventHubNamespaceName
output eventHubName string = eventHubName
output eventHubResourceId string = eventHub.id

// Note: Output secrets and connectiong string is considered as bad practice
output eventHubConnectionString string = eventHubConnectionStringListenSend
