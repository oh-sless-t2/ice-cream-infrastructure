@description('The name seed for your application. Check outputs for the actual name and url')
param appName string = 'ratings'

@description('Name of the CosmosDb Account')
param databaseAccountId string = toLower('db-${appName}')

@description('Name of the web app host plan')
param hostingPlanName string = 'plan-${appName}'

//Making the name unique - if this fails, it's because the name is already taken (and you're really unlucky!)
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'
var storageAccountName = substring(toLower('stor${appName}${uniqueString(resourceGroup().id, appName)}'),0,23)

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: resourceGroup().location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${fnAppUai.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': AppInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name };EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet'
        }
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: cosmos.outputs.connstr
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
      ]
    }
  }
}
output appUrl string = functionApp.properties.defaultHostName
output appName string = functionApp.name

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${webAppName}'
  location: resourceGroup().location
}

// resource webAppConfig 'Microsoft.Web/sites/config@2019-08-01' = { 
//   parent: webApp
//   name: 'web'
//   properties: {
//     scmType: 'ExternalGit'
//   }
// }

// resource webAppLogging 'Microsoft.Web/sites/config@2021-02-01' = {
//   parent: webApp
//   name: 'logs'
//   properties: {
//     applicationLogs: {
//       fileSystem: {
//         level: 'Warning'
//       }
//     }
//     httpLogs: {
//       fileSystem: {
//         enabled: true
//         retentionInDays: 1
//         retentionInMb: 25
//       }
//     }
//   }
// }

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}


resource hostingPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: hostingPlanName
  location: resourceGroup().location
  sku: {
    name: 'Y1' 
    tier: 'Dynamic'
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
  }
}

// resource codeDeploy 'Microsoft.Web/sites/sourcecontrols@2021-01-15' = {
//   parent: functionApp
//   name: 'web'
//   properties: {
//     repoUrl:'https://github.com/oh-sless-t2/dotnet-appsvc-cosmosdb-bottleneck'
//     branch: 'main'
//     isManualIntegration: true
//   }
// }

//Using the latest api versions to deploy Cosmos actually stops the app code from working. So at least for the time being, it's going to just use the old API versions to create the MongoDb in CosmosDb.
module cosmos 'cosmos-sql.bicep' = { 
  name: 'cosmosDb'
  params: {
    databaseAccountId: databaseAccountId
  }
}

module apim 'apim.bicep' = {
  name: 'apim'
  params: {
    nameSeed: 'icecream'
    AppInsightsName: AppInsights.name
  }
}

// module apis 'apim-apis.bicep' = {
//   name: 'apim-apis'
//   params: {
//     apimName: apim.outputs.ApimName
//   }
// }

module akv 'kv.bicep' = {
  name: 'keyvault'
  params: {
    keyvaultName: 'kvicecream'
    apimUaiName: apim.outputs.apimUaiName
    fnAppUaiName: fnAppUai.name
  }
}
