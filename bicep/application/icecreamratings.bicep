@description('The name seed for all your other resources.')
param resNameSeed string = 'icecre4'

@description('The application name of the Function App')
param appName string = 'ratings'

@allowed([
  'dev'
  'prod'
])
param environment string = 'dev'

param cosmosDbCollecionName string = appName

var isProdEnvironment = environment == 'prod'
@description('Creating the serverless app stack')
module serverlessapp '../archetype/apimCosmosApp.bicep' = {
  name: 'serverlessapp-${resNameSeed}'
  params: {
    resNameSeed: resNameSeed
    appName: appName
    apiManagementSku: 'Consumption'
    AppGitRepoUrl: 'https://github.com/oh-sless-t2/ice-cream-rating-api'
    enableKeyVaultSoftDelete: isProdEnvironment
    cosmosDbDatabaseName: 'icecream'
    cosmosDbCollectionName: cosmosDbCollecionName
    cosmosDbPartitionKey: 'productId'
  }
}

@description('Create a web test on the functionApp')
module webTest '../foundation/appinsightswebtest.bicep' = {
  name: 'WebTest-${appName}'
  params: {
    Name: appName
    AppInsightsName: serverlessapp.outputs.AppInsightsName
    WebTestUrl:  'https://${ serverlessapp.outputs.ApplicationUrl}/api/GetRatings/cc20a6fb-a91f-4192-874d-132493685376'
  }
}

@description('Creating application specific APIM configuration')
module apis 'icecreamratings-apimspec.bicep' = {
  name: 'apim-apis'
  params: {
    resNameSeed: resNameSeed
    apimName: serverlessapp.outputs.ApimName
    appInsightsName: serverlessapp.outputs.AppInsightsName
    apimLoggerId: serverlessapp.outputs.ApimLoggerId
    ratingsApiBaseUrl: 'https://${ serverlessapp.outputs.ApplicationUrl}/api/'
  }
}
