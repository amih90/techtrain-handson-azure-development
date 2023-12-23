targetScope = 'resourceGroup'

@description('Primary location for all resources')
param location string = resourceGroup().location

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
param identity object = {
  type: 'None'
}

@description('''Array of databases objects
  {
    name: string,
    properties: [ReadWriteDatabaseProperties?](https://learn.microsoft.com/en-us/azure/templates/microsoft.kusto/clusters/databases?pivots=deployment-language-bicep#readwritedatabaseproperties),
    scriptsContent: array[str]
  }''')
param databases array = []


module cluster './adx-cluster.bicep' = {
  name: 'adx-cluster-${clusterName}'
  params: {
    clusterName: clusterName
    location: location
    sku: sku
    tags: tags
    identity: identity
    properties: properties
    zones: zones
    workspaceId: workspaceId
  }
}


@batchSize(1)
module db './adx-db.bicep' = [for database in databases: {
  name: 'adx-db-${clusterName}-${database.name}'
  dependsOn: [
    cluster
  ]
  params: {
    location: location
    clusterName: clusterName
    databaseName: database.name
    properties: database.properties
    scriptsContent: database.scriptsContent
  }
}]

output clusterResourceId string = cluster.outputs.clusterResourceId
output clusterName string = clusterName
