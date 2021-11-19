@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

resource redis 'Microsoft.Cache/redis@2020-12-01' = {
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

output redisconnectionstring string = '${redis.properties.hostName}:${redis.properties.port},password=${listKeys(redis.id,'2020-12-01').primaryKey},ssl=True,abortConnect=False'
output redisfullresourceid string = '${environment().resourceManager}${substring(redis.id,1)}'
