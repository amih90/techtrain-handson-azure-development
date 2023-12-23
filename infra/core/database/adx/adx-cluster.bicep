@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the Azure Data Explorer Cluster. Use only lowercase letters and numbers.')
param clusterName string

@description('Specifies the properties of the Azure Data Explorer Cluster, for instance enableStreamingIngest')
param properties object = {
  enableStreamingIngest: false
  enablePurge: false
  enableDoubleEncryption: false
  enableDiskEncryption: false
  trustedExternalTenants: []
  enableAutoStop: true
}

@description('Specifies the sku')
param sku object = {
  capacity: 1
  name: 'Dev(No SLA)_Standard_E2a_v4'
  tier: 'Basic'
}

@description('The availability zones of the Azure Data Explorer Cluster.')
param zones array = [
  '1'
]

@description('The Azure Data Explorer Cluster tags.')
param tags object = {}

@description('The log analytics workspace id used for logging & monitoring')
param workspaceId string = ''

@description('The identity of the cluster, if configured (https://learn.microsoft.com/en-us/azure/templates/microsoft.kusto/clusters?pivots=deployment-language-bicep#identity).')
param identity object

@description('The diagnostic log categories')
param diagnosticLogCategories array = [
  'SucceededIngestion'
  'FailedIngestion'
  'IngestionBatching'
  'Command'
  'Query'
  'TableUsageStatistics'
  'TableDetails'
]

resource cluster 'Microsoft.Kusto/clusters@2022-12-29' = {
  name: clusterName
  location: location
  sku: sku
  tags: tags
  identity: identity
  properties: properties
  zones: zones
}

// resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'diagnostics'
//   scope: cluster
//   properties: {
//     workspaceId: workspaceId
//     logs: [for category in diagnosticLogCategories: {
//       category: category
//       enabled: true
//     }]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }


output clusterResourceId string = cluster.id
