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

@description('Log Analytics ResourceId')
param logId string

@description('Diagnostic categories to log')
param logCategory array = [
  'ConnectedClientList'
]

resource diags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'aksDiags'
  scope: redis
  properties: {
    workspaceId: logId
    logs: [for diagCategory in logCategory: {
      category: diagCategory
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output redishostnmame string = redis.properties.hostName
output redisconnectionstring string = '${redis.properties.hostName}:${redis.properties.sslPort},password=${listKeys(redis.id,'2020-12-01').primaryKey},ssl=True,abortConnect=False'
output redisfullresourceid string = '${environment().resourceManager}${substring(redis.id,1)}'
