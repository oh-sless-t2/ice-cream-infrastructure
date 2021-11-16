// This file uses the newer API's for Cosmos, however the node app doesn't cope well
// Leaving the file here for reference, but know that it's not used by main.bicep

@description('Name of the CosmosDb Account')
param databaseAccountId string

param databaseAccountLocation string =resourceGroup().location

param databaseName string = 'icecream'
param collectionName string = 'ratings'
param partitionkey string= 'productId'

param fnAppUaiName string

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: fnAppUaiName
}

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
          '/${partitionkey}'
        ]
        kind: 'Hash'
      }
    }
  }
}

output accountId string = cosmosDbDatabase.id
output connstr string = first(listConnectionStrings('Microsoft.DocumentDb/databaseAccounts/${databaseAccountId}', '2015-04-08').connectionStrings).connectionString
output accountName string = cosmosDbAccount.name

var readWriteRoleDefinitionId = guid(cosmosDbAccount.name, 'ReadWriteRole')
resource cosmosReadWriteRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-03-01-preview' = {
  name: readWriteRoleDefinitionId
  parent: cosmosDbAccount
  properties: {
    assignableScopes: [
      cosmosDbAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
        ]
        notDataActions: []
      }
    ]
    roleName: 'Reader Writer'
    type: 'CustomRole'
  }
}

var readWriteRoleAppAssignmentId = guid(cosmosDbAccount.name, 'ReadWriteRole', 'App')
resource cosmosReadWriteAppAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-03-01-preview' = {
  name: '${cosmosDbAccount.name}/${readWriteRoleAppAssignmentId}'
  properties: {
    principalId: reference(fnAppUai.id, '2016-08-01', 'Full').identity.principalId
    roleDefinitionId: cosmosReadWriteRoleDefinition.id
    scope: cosmosDbAccount.id
  }
}
