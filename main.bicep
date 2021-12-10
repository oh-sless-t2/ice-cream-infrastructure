@description('The name seed for your functionapp. Check outputs for the actual name and url')
param appName string = 'ratings'

@description('The name seed for all your other resources.')
param resNameSeed string = 'icecream'

@allowed([
  'Developer'
  'Premium'
  'Consumption'
])
param apiManagementSku string = 'Consumption'

@description('Restricts inbound traffic to your functionapp, to just from APIM')
param restrictTrafficToJustAPIM bool = false

param deployWebTests bool =true

@description('Soft Delete protects your Vault contents and should be used for serious environments')
param enableKeyVaultSoftDelete bool = true

//Making the name unique - if this fails, it's because the name is already taken (and you're really unlucky!)
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'
//var storageAccountName = substring(toLower('stor${appName}${uniqueString(resourceGroup().id, appName)}'),0,23)
param fnAppIdentityName string = 'id-app-${appName}-${uniqueString(resourceGroup().id, appName)}'


//Creating the function App identity here as otherwise it'll cause circular problems
resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: fnAppIdentityName
  location: resourceGroup().location
}

var kv_cosmosconnectionstring = '@Microsoft.KeyVault(SecretUri=${akv.outputs.secretUriWithVersion})'
module functionApp 'functionapp.bicep' = {
  name: 'functionApp-${appName}'
  params: {
    appName: appName
    AppInsightsName: AppInsights.name
    CosmosConnectionString: kv_cosmosconnectionstring //cosmos.outputs.connstr
    restrictTrafficToJustAPIM: restrictTrafficToJustAPIM
    fnAppIdentityName: fnAppUai.name
  }
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: webAppName
  location: resourceGroup().location
  kind: 'web'
  tags: {
    //This looks nasty, but see here: https://github.com/Azure/bicep/issues/555
    'hidden-link:${resourceGroup().id}/providers/Microsoft.Web/sites/${webAppName}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: log.id
    IngestionMode: 'LogAnalytics'
  }
}

var appInsights_webTestUrl = 'https://${functionApp.outputs.appUrl}/api/GetRatings/cc20a6fb-a91f-4192-874d-132493685376'
resource urlTest 'Microsoft.Insights/webtests@2018-05-01-preview' = if(deployWebTests) {
  name: 'TestRatingsAPI'
  location: resourceGroup().location
  kind: 'ping'
    tags: {
    'hidden-link:${AppInsights.id}': 'Resource'
  }
  properties: {
    Name: 'TestRatingsAPI'
    Kind: 'standard'
    SyntheticMonitorId: 'TestRatingsAPI'
    Frequency: 300
    Timeout: 30
    Enabled:true
    Request: {
      FollowRedirects: false
      HttpVerb: 'Get'
      RequestUrl: appInsights_webTestUrl
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck:false
    }
    Locations: [
      {
        Id: 'emea-nl-ams-azr'
      }
      {
        Id: 'emea-se-sto-edge'
      }
      {
        Id: 'emea-ru-msa-edge'
      }
      {
        Id: 'emea-gb-db3-azr'
      }
      {
        Id: 'emea-ch-zrh-edge'
      }
    ]
  }
}


@description('The Log Analytics retention period')
param retentionInDays int = 30

var log_name = 'log-${resNameSeed}'

resource log 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: log_name
  location: resourceGroup().location
  properties: {
    retentionInDays: retentionInDays
  }
}

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

module cosmos 'cosmos-sql.bicep' = {
  name: 'cosmosDb'
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
module akv 'kv.bicep' = {
  name: 'keyvault'
  params: {
    nameSeed: 'kvicecream'
    enableSoftDelete: enableKeyVaultSoftDelete
    apimUaiName:  apim.outputs.apimUaiName
    fnAppUaiName: fnAppUai.name
    secretName: 'RatingsCosmosDbConnectionString'
    secretValue: cosmos.outputs.connstr
  }
}

// --------------API Management-----------------------
module apim 'apim.bicep' =  {
  name: 'apim'
  params: {
    nameSeed: resNameSeed
    AppInsightsName: AppInsights.name
    sku: apiManagementSku
    logId: log.id
  }
}

@description('This bicep module is split out as its lifecycle will be independant, post initial deployment')
module apis 'apim-apis.bicep' = {
  name: 'apim-apis'
  params: {
    apimName: apim.outputs.ApimName
    AppInsightsName: AppInsights.name
  }
}

// --------------------Load testing-------------------
param createLoadTests bool = false
param loadTestOwnerObjectId string = ''
module loadtest 'loadtest.bicep' = if(createLoadTests) {
  name: 'loadtest'
  params: {
    loadtestname: '${appName}-test'
    LoadTestTargetUrl: functionApp.outputs.appUrl
    location: 'eastus' //public preview region
    loadTestOwnerUser: loadTestOwnerObjectId
  }
}
