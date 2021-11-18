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
  'Consumption'
])
param sku string = 'Consumption'

param useRedisCache bool = true

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

param AppInsightsName string = ''


var apiManagementServiceName = 'apim-${nameSeed}-${substring(sku,0,3)}-${uniqueString(resourceGroup().id, nameSeed)}'

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: sku=='Consumption' ? 0 :  skuCount
  }
  zones: ((length(availabilityZones) == 0 || sku!='Premium') ? json('null') : availabilityZones)
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

resource apimPolicy 'Microsoft.ApiManagement/service/policies@2019-12-01' = {
  name: '${apim.name}/policy'
  properties:{
    format: 'rawxml'
    value: '<policies><inbound /><backend><forward-request /></backend><outbound /><on-error /></policies>'
  }
}

resource apiUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-apim-${nameSeed}'
  location: location
}
output apimUaiName string = apiUai.name


resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = if(!empty(AppInsightsName)) {
  name: AppInsightsName
}

resource redis 'Microsoft.Cache/redis@2020-12-01' = if(useRedisCache) {
  name: 'redis-${nameSeed}'
  location: resourceGroup().location
  properties: {
    sku: {
      capacity: 0
      family: 'C'
      name: 'Basic'
    }
    redisVersion: '6'
    minimumTlsVersion: '1.2'
  }
}
output redishostnmame string = redis.properties.hostName

var redisconnectionstring = '${redis.properties.hostName}:${redis.properties.port},password=${listKeys(redis.id,'2020-12-01').primaryKey},ssl=True,abortConnect=False'
var redisfullresourceid = '${environment().resourceManager}${substring(redis.id,1)}'

resource apimcache 'Microsoft.ApiManagement/service/caches@2020-12-01' = {
  name: resourceGroup().location
  parent: apim
  properties: {
    connectionString: redisconnectionstring
    useFromLocation: resourceGroup().location
    description: redis.properties.hostName
    resourceId: redisfullresourceid
  }
}

// Create Logger and link logger
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2019-12-01' = {
  name: '${apim.name}/${apim.name}-logger'
  properties:{
    resourceId: AppInsights.id
    loggerType: 'applicationInsights'
    credentials:{
      instrumentationKey: AppInsights.properties.InstrumentationKey
    }
    description: 'APIM logger for Application Insights'
  }
}
