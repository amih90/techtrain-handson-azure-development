param clusterName string
param clusterLocation string
param databaseName string
param name string
@allowed([
  'EventGrid', 'EventHub', 'IotHub', 'CosmosDb'
])
param kind string = 'EventHub'
param properties object

resource Cluster 'Microsoft.Kusto/clusters@2022-02-01' existing = {
  name: clusterName
}

resource Database 'Microsoft.Kusto/clusters/databases@2022-02-01' existing = {
  name: databaseName
  parent: Cluster
}

resource DataConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2023-05-02' = {
  name: name
  location: clusterLocation
  parent: Database
  kind: kind
  properties: properties
}
