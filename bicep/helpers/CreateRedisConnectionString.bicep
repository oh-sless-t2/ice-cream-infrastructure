/*
This module demonstrates an interesting pattern, where the behaviour of ListKeys is;
"ListKeys requires a value that can be calculated at the start of the deployment"
However we need to delay the evaluation of ListKeys until after the resource is created in a module.
*/
param redisName string
param nameOfSomethingToWaitFor string

resource redis 'Microsoft.Cache/redis@2020-12-01' existing = {
  name: redisName
}

var redisConnectionString = '${redis.properties.hostName}:${redis.properties.sslPort},password=${redis.listKeys().primaryKey},ssl=True,abortConnect=False'

output connectionstring string = redisConnectionString
output TheThingWeWaitedFor string = nameOfSomethingToWaitFor
