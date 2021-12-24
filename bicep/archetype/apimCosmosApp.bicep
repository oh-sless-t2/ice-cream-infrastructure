/*
  A single function app that uses CosmosDb, fronted by APIM.
  As an Archetype there is no specific application information, just the right configuration for a standard App deployment.
*/

@description('The name seed for your functionapp. Check outputs for the actual name and url')
param appName string

@description('The name seed for all your other resources.')
param resNameSeed string

@allowed([
  'Developer'
  'Premium'
  'Consumption'
])
@description('The Sku of APIM thats appropriate for the App')
param apiManagementSku string = 'Consumption'

@description('Restricts inbound traffic to your functionapp, to just from APIM')
param restrictTrafficToJustAPIM bool = false

@description('Soft Delete protects your Vault contents and should be used for serious environments')
param enableKeyVaultSoftDelete bool = true

@description('Needs to be unique as ends up as a public endpoint')
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'

// --------------------App Identity-------------------
//Creating the function App identity here as otherwise it'll cause circular problems in the modules
@description('The Azure Managed Identity Name assigned to the FunctionApp')
param fnAppIdentityName string = 'id-app-${appName}-${uniqueString(resourceGroup().id, appName)}'

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: fnAppIdentityName
  location: resourceGroup().location
}

// --------------------Function App-------------------
@description('The ful publicly accessible external Git(Hub) repo url')
param AppGitRepoUrl string

@description('Grabbing the KeyVault Connectionstring secret uri')
var kv_cosmosconnectionstring = '@Microsoft.KeyVault(SecretUri=${cosmos.outputs.connstrSecretUriWithVersion})'
module functionApp '../foundation/functionapp.bicep' = {
  name: 'functionApp-${appName}'
  params: {
    appName: appName
    webAppName: webAppName
    AppInsightsName: appInsights.outputs.name
    CosmosConnectionString: kv_cosmosconnectionstring
    restrictTrafficToJustAPIM: restrictTrafficToJustAPIM
    fnAppIdentityName: fnAppUai.name
    repoUrl: AppGitRepoUrl
  }
}
@description('The raw ')
output ApplicationUrl string = functionApp.outputs.appUrl

// --------------------App Insights-------------------
module appInsights '../foundation/appinsights.bicep' = {
  name: 'appinsights-${appName}'
  params: {
    appName: webAppName
    logAnalyticsId: log.outputs.id
  }
}
output AppInsightsName string = appInsights.outputs.name

// --------------------Log Analytics-------------------
module log '../foundation/loganalytics.bicep' = {
  name: 'log-${resNameSeed}'
  params: {
    resNameSeed: resNameSeed
    retentionInDays: 30
  }
}

// --------------CosmosDb-----------------------
@description('Name of the CosmosDb Account')
param cosmosDbAccountName string = 'db-${resNameSeed}-${uniqueString(resourceGroup().id, appName)}'
var cleanCosmosDbName = toLower(cosmosDbAccountName)
param cosmosDbResourceGroupName string = resourceGroup().name

param cosmosDbDatabaseName string
param cosmosDbCollectionName string
param cosmosDbPartitionKey string

@allowed([
  'Provisioned'
  'Serverless'
])
param cosmosDbCapacityMode string = 'Serverless'
param cosmosDbFreeTier bool = false

module cosmos '../foundation/cosmos-sql.bicep' = {
  name: 'cosmosDb-${resNameSeed}'
  scope: resourceGroup(cosmosDbResourceGroupName)
  params: {
    databaseAccountName: cleanCosmosDbName
    databaseName: cosmosDbDatabaseName
    collectionName: cosmosDbCollectionName
    partitionkey: cosmosDbPartitionKey
    AppIdentityName: fnAppUai.name
    AppIdentityRG: resourceGroup().name
    capacityMode: cosmosDbCapacityMode
    freeTier: cosmosDbFreeTier
    keyvaultName: akv.outputs.name
    keyvaultConnectionStringSecretName: '${appName}CosmosDbConnectionString'
  }
}

module akv '../foundation/kv.bicep' = {
  name: 'keyvault-${resNameSeed}'
  params: {
    nameSeed: resNameSeed
    enableSoftDelete: enableKeyVaultSoftDelete
    UaiSecretReaderNames: [
      fnAppUai.name
      apim.outputs.apimUaiName
    ]
  }
}


// resource appUaiRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name:
//   scope: akv
// }

// --------------API Management-----------------------
module apim '../foundation/apim.bicep' =  {
  name: 'apim-${resNameSeed}'
  params: {
    nameSeed: resNameSeed
    AppInsightsName: appInsights.outputs.name
    sku: apiManagementSku
    logId: log.outputs.id
  }
}
output ApimName string = apim.outputs.ApimName
output ApimLoggerId string = apim.outputs.loggerId

// --------------------Load testing-------------------
param createLoadTests bool = false
param loadTestOwnerObjectId string = ''
module loadtest '../foundation/loadtest.bicep' = if(createLoadTests) {
  name: 'loadtest-${resNameSeed}'
  params: {
    loadtestname: '${appName}-test'
    LoadTestTargetUrl: functionApp.outputs.appUrl
    location: 'eastus' //public preview region
    loadTestOwnerUser: loadTestOwnerObjectId
  }
}
