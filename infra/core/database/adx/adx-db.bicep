@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the Azure Data Explorer Cluster. Use only lowercase letters and numbers.')
param clusterName string

@description('Name of the Azure Data Explorer Database. Use only lowercase letters and numbers.')
param databaseName string

@description('Specifies the properties of the Azure Data Explorer Database')
param properties object

@description('Array of scripts')
param scriptsContent array = []

resource db 'Microsoft.Kusto/clusters/databases@2023-05-02' = {
  name: '${clusterName}/${databaseName}'
  location: location
  kind: 'ReadWrite'
  properties: properties
}

@batchSize(1)
resource script 'Microsoft.Kusto/clusters/databases/scripts@2022-12-29' = [for (scriptContent, i) in scriptsContent: {
  name: '${databaseName}-script-${i}'
  parent: db
  properties: {
    continueOnErrors: false
    scriptContent: scriptContent
  }
}]
