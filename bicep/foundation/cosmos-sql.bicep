@description('Name of the CosmosDb Account')
@minLength(3)
@maxLength(44)
param databaseAccountName string

param databaseName string
param collectionName string
param partitionkey string

param zoneRedundant bool = false

@allowed([
  'Provisioned'
  'Serverless'
])
@description('')
param capacityMode string = 'Serverless'

@description('Leverage the free tier (Provisioned capacity tier only) (One per subscription!)')
param freeTier bool = false

@description('The User Assigned Identity of an App to be given Read/Write RBAC')
param AppIdentityName string = ''
param AppIdentityRG string = resourceGroup().name //In the next version of Bicep we'll be able to pass resources between modules - so Name/Rg will get refactored to 1 param

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(!empty(AppIdentityName)) {
  name: AppIdentityName
  scope:  resourceGroup(AppIdentityRG)
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-07-01-preview' = {
  kind: 'GlobalDocumentDB'
  name: databaseAccountName
  location: resourceGroup().location
  properties: {
    databaseAccountOfferType: 'Standard'
    capabilities: capacityMode=='Serverless' ? [
      {
        name: 'EnableServerless'
      }
    ] : []
    enableFreeTier: capacityMode=='Provisioned' && freeTier
    createMode: 'Default'
    // capacity: {
    //   totalThroughputLimit: 4000
    // }
    locations: [
      {
        locationName: '${resourceGroup().location}'
        failoverPriority:0
        isZoneRedundant: zoneRedundant
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
//output connstr string = first(listConnectionStrings('Microsoft.DocumentDb/databaseAccounts/${databaseAccountName}', '2015-04-08').connectionStrings).connectionString
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
var readWriteRoleAppAssignmentId  = guid(cosmosDbAccount.name, 'ReadWriteRole', 'App')

//use the output readWriteRoleAppAssignmentId in your calling module with something like this.
resource cosmosReadWriteAppAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-03-01-preview' = if(!empty(AppIdentityName)) {
  name: readWriteRoleAppAssignmentId
  parent: cosmosDbAccount
  properties: {
    principalId: fnAppUai.properties.principalId
    roleDefinitionId: cosmosReadWriteRoleDefinition.id
    scope: cosmosDbAccount.id
  }
}
