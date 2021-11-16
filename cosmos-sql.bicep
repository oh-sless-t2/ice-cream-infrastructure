// This file uses the newer API's for Cosmos, however the node app doesn't cope well
// Leaving the file here for reference, but know that it's not used by main.bicep

@description('Name of the CosmosDb Account')
param databaseAccountId string

param databaseAccountLocation string =resourceGroup().location

param databaseName string = 'icecream'
param collectionName string = 'ratings'

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  kind: 'GlobalDocumentDB'
  name: databaseAccountId
  location: databaseAccountLocation
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: '${resourceGroup().location}'
        failoverPriority:0
        isZoneRedundant: false
      }
    ]
  }
}
output databaseAccountId string = cosmosDbAccount.id

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-07-01-preview' = {
  parent: cosmosDbAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-01-15' = {
  parent: cosmosDbDatabase
  name: collectionName
  properties: {
    resource: {
      id: collectionName
      partitionKey: {
        paths: [
          '/productId'
        ]
        kind: 'Hash'
      }
    }
  }
}

output accountId string = cosmosDbDatabase.id
output connstr string = first(listConnectionStrings('Microsoft.DocumentDb/databaseAccounts/${databaseAccountId}', '2015-04-08').connectionStrings).connectionString
