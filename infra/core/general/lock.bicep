targetScope = 'resourceGroup'

param name string
param resourceGroupName string = resourceGroup().name

resource lock 'Microsoft.Authorization/locks@2016-09-01' = {
  name: name
  properties: {
    level: 'CanNotDelete'
    notes: 'Resource group ${resourceGroupName} should not be deleted.'
  }
}
