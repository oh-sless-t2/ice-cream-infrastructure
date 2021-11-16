@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'Gobyers'

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Premium'
])
param sku string = 'Developer'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'gdogg@microsoft.com'

@description('The instance size of this API Management service.This should be in multiple of zones getting deployed.')
param skuCount int = 1

@description('Zone numbers e.g. 1,2,3.')
param availabilityZones array = [
  '1'
  '2'
  '3'
]

var apiManagementServiceName_var = 'apim-${nameSeed}'
var keyvaultName = 'kv${nameSeed}'

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' = {
  name: apiManagementServiceName_var
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  zones: ((length(availabilityZones) == 0 || sku=='Developer') ? json('null') : availabilityZones)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apiUai.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}
output ApimName string = apim.name

resource apiUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${nameSeed}'
  location: location
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' =  {
  name: keyvaultName
  location: location
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
    ]
    enableSoftDelete: true
  }
}
