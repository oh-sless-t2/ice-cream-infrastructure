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
param apiManagementSku string = 'Consumption'

@description('Restricts inbound traffic to your functionapp, to just from APIM')
param restrictTrafficToJustAPIM bool = false

//param deployWebTests bool =true

@description('Soft Delete protects your Vault contents and should be used for serious environments')
param enableKeyVaultSoftDelete bool = true

@description('Needs to be unique as ends up as a public endpoint')
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'

param fnAppIdentityName string = 'id-app-${appName}-${uniqueString(resourceGroup().id, appName)}'

//Creating the function App identity here as otherwise it'll cause circular problems
resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: fnAppIdentityName
  location: resourceGroup().location
}

// --------------------Function App-------------------
param AppGitRepoUrl string
var kv_cosmosconnectionstring = '@Microsoft.KeyVault(SecretUri=${akv.outputs.secretUriWithVersion})'
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


// var appInsights_webTestUrl = 'https://${functionApp.outputs.appUrl}/api/GetRatings/cc20a6fb-a91f-4192-874d-132493685376'
// resource urlTest 'Microsoft.Insights/webtests@2018-05-01-preview' = if(deployWebTests) {
//   name: 'TestRatingsAPI'
//   location: resourceGroup().location
//   kind: 'ping'
//     tags: {
//     'hidden-link:${appInsights.outputs.id}': 'Resource'
//   }
//   properties: {
//     Name: 'TestRatingsAPI'
//     Kind: 'standard'
//     SyntheticMonitorId: 'TestRatingsAPI'
//     Frequency: 300
//     Timeout: 30
//     Enabled:true
//     Request: {
//       FollowRedirects: false
//       HttpVerb: 'Get'
//       RequestUrl: appInsights_webTestUrl
//       ParseDependentRequests: false
//     }
//     ValidationRules: {
//       ExpectedHttpStatusCode: 200
//       SSLCheck:false
//     }
//     Locations: [
//       {
//         Id: 'emea-nl-ams-azr'
//       }
//       {
//         Id: 'emea-se-sto-edge'
//       }
//       {
//         Id: 'emea-ru-msa-edge'
//       }
//       {
//         Id: 'emea-gb-db3-azr'
//       }
//       {
//         Id: 'emea-ch-zrh-edge'
//       }
//     ]
//   }
// }



// --------------CosmosDb-----------------------
@description('Name of the CosmosDb Account')
param cosmosDbAccountName string = 'db-${resNameSeed}-${uniqueString(resourceGroup().id, appName)}'
var cleanCosmosDbName = toLower(cosmosDbAccountName)
param cosmosDbResourceGroupName string = resourceGroup().name

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
    databaseName: 'icecream'
    collectionName:'ratings'
    partitionkey: 'productId'
    AppIdentityName: fnAppUai.name
    AppIdentityRG: resourceGroup().name
    capacityMode: cosmosDbCapacityMode
    freeTier: cosmosDbFreeTier
  }
}

// Can't make assignment here.  Scope problem. Need to be in the CosmosRG (module)
// resource cosmosReadWriteAppAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-03-01-preview' =  {
//   name: '${cleanCosmosDbName}/${guid(resourceGroup().id, fnAppIdentityName)}'
//   properties: {
//     principalId: fnAppUai.properties.principalId
//     roleDefinitionId: cosmos.outputs.readWriteRoleAppAssignmentId
//     scope: cosmos.outputs.accountId
//   }
// }


// --------------Key Vault-----------------------
var cosmosConnString = first(listConnectionStrings('Microsoft.DocumentDb/databaseAccounts/${cleanCosmosDbName}', '2015-04-08').connectionStrings).connectionString

module akv '../foundation/kv.bicep' = {
  name: 'keyvault-${resNameSeed}'
  params: {
    nameSeed: 'kvicecream'
    enableSoftDelete: enableKeyVaultSoftDelete
    apimUaiName:  apim.outputs.apimUaiName
    fnAppUaiName: fnAppUai.name
    secretName: 'RatingsCosmosDbConnectionString'
    secretValue: cosmosConnString
  }
}

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
