@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

param enableSoftDelete bool = true

@minLength(1)
@description('Pass an array of UAI names to give the GET secret access policy')
param UaiSecretReaderNames array


var kvRawName = replace('kv-${nameSeed}-${uniqueString(resourceGroup().id, nameSeed)}','-','')
var kvName = length(kvRawName) > 24 ? substring(kvRawName,0,23) : kvRawName

resource uais 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing =  [for uai in UaiSecretReaderNames : {
  name: uai
}]

var tenantId = uais[0].properties.tenantId

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' =  {
  name: kvName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenantId
    accessPolicies: [ for (uai, index) in UaiSecretReaderNames : {
        tenantId: uais[index].properties.tenantId
        objectId: uais[index].properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }]
    enableSoftDelete: enableSoftDelete
  }
}
output name string = kvName
