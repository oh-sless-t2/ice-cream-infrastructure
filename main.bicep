@description('The name seed for your functionapp. Check outputs for the actual name and url')
param appName string = 'ratings'

@description('The name seed for all your other resources.')
param resNameSeed string = 'icecream'

@description('Name of the CosmosDb Account')
param databaseAccountId string = toLower('db-${resNameSeed}')

//TODO: Change to param in further refactor
var createApimService = true

@description('Restricts inbound traffic to your functionapp, to just from APIM')
param restrictTrafficToJustAPIM bool = false


//Making the name unique - if this fails, it's because the name is already taken (and you're really unlucky!)
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'
//var storageAccountName = substring(toLower('stor${appName}${uniqueString(resourceGroup().id, appName)}'),0,23)
param fnAppIdentityName string = 'id-app-${appName}-${uniqueString(resourceGroup().id, appName)}'


//Creating the function App identity here as otherwise it'll cause circular problems
resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: fnAppIdentityName
  location: resourceGroup().location
}

module functionApp 'functionapp.bicep' = {
  name: 'functionApp-${appName}'
  params: {
    appName: appName
    AppInsightsName: AppInsights.name
    CosmosConnectionString: cosmos.outputs.connstr
    restrictTrafficToJustAPIM: restrictTrafficToJustAPIM && createApimService
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

module cosmos 'cosmos-sql.bicep' = { 
  name: 'cosmosDb'
  params: {
    databaseAccountId: databaseAccountId
    databaseName: 'icecream'
    collectionName:'ratings'
    partitionkey: 'productId'
    fnAppUaiName: fnAppUai.name
  }
}

module akv 'kv.bicep' = {
  name: 'keyvault'
  params: {
    nameSeed: 'kvicecream'
    apimUaiName:  apim.outputs.apimUaiName
    fnAppUaiName: fnAppUai.name
    secretName: 'RatingsCosmosDbConnectionString'
    secretValue: cosmos.outputs.connstr
  }
}

module apim 'apim.bicep' = if(createApimService) {
  name: 'apim'
  params: {
    nameSeed: resNameSeed
    AppInsightsName: AppInsights.name
  }
}

//APIM doesn't like the fast follow of API's
//Do this part in another pipeline calling the bicep file
// module apis 'apim-apis.bicep' = {
//   name: 'apim-apis'
//   params: {
//     apimName: apim.outputs.ApimName
//   }
// }
