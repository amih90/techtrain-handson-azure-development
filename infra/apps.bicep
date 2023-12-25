targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@secure()
param apiPackageUri string

@secure()
param webPackageUri string

param apiServiceName string = ''
param webServiceName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))


// resource api 'Microsoft.Web/sites@2022-03-01' existing = {
//   name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
// }

// resource apiZipDeploy 'Microsoft.Web/sites/extensions@2022-03-01' = {
//   parent: api
//   name: any('ZipDeploy')
//   properties: {
//     packageUri: apiPackageUri
//   }
// }

resource web 'Microsoft.Web/sites@2022-03-01' existing = {
  name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
}

resource webZipDeploy 'Microsoft.Web/sites/extensions@2022-03-01' = {
  parent: web
  name: any('ZipDeploy')
  properties: {
    packageUri: webPackageUri
  }
}
