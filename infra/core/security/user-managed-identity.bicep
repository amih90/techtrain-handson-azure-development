@description('Primary location for all resources')
param location string = resourceGroup().location

@description('The resource name')
@minLength(3)
@maxLength(128)
param name string

resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
}

output resourceId string = userManagedIdentity.id
output properties object = userManagedIdentity.properties
