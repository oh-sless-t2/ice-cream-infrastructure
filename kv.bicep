@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

param apimUaiName string
param fnAppUaiName string

var kvName = replace('kv-${nameSeed}-${uniqueString(resourceGroup().id, nameSeed)}','-','')

resource apiUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimUaiName
}

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: fnAppUaiName
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' =  {
  name: kvName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: apiUai.properties.tenantId
    accessPolicies: [
      {
        tenantId: apiUai.properties.tenantId
        objectId: apiUai.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: fnAppUai.properties.tenantId
        objectId: fnAppUai.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    enableSoftDelete: true
  }
}
