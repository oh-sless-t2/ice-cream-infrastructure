@description('Name of the CosmosDb Account')
param databaseAccountId string

param databaseName string
param collectionName string
param partitionkey string

param fnAppUaiName string

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: fnAppUaiName
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  kind: 'GlobalDocumentDB'
  name: databaseAccountId
  location: resourceGroup().location
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

//REF: https://joonasw.net/view/access-data-in-cosmos-db-with-managed-identities
var readWriteRoleAppAssignmentId = guid(cosmosDbAccount.name, 'ReadWriteRole', 'App')
resource cosmosReadWriteAppAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-03-01-preview' = {
  name: '${cosmosDbAccount.name}/${readWriteRoleAppAssignmentId}'
  properties: {
    principalId: fnAppUai.properties.principalId
    roleDefinitionId: cosmosReadWriteRoleDefinition.id
    scope: cosmosDbAccount.id
  }
}
