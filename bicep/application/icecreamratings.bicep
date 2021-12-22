
@description('The name seed for all your other resources.')
param resNameSeed string = 'icecream'

@description('Creating the serverless app stack')
module serverlessapp '../archetype/apimCosmosApp.bicep' = {
  name: 'serverlessapp-${resNameSeed}'
  params: {
    resNameSeed: resNameSeed
    appName: 'ratings'
    apiManagementSku: 'Consumption'
    AppGitRepoUrl: 'https://github.com/oh-sless-t2/ice-cream-rating-api'
  }
}

@description('Creating APIs in APIM for the app')
module apis 'apim-apis.bicep' = {
  name: 'apim-apis'
  params: {
    apimName: serverlessapp.outputs.ApimName
    AppInsightsName: serverlessapp.outputs.AppInsightsName
  }
}

@description('Creating APIs in APIM for the app')
module userApi '../foundation/apim-api.bicep' = {
  name: 'userApi-apim-${resNameSeed}'
  params: {
    apimName: serverlessapp.outputs.ApimName
    apimLoggerId: serverlessapp.outputs.ApimLoggerId
    AppInsightsName: serverlessapp.outputs.AppInsightsName
    servicename: 'Users2'
    baseUrl: 'https://serverlessohapi.azurewebsites.net/api/'
    serviceApimPath: 'users2'
    serviceDisplayName: 'Users API2'
    apis: [
      {
        method: 'GET'
        urlTemplate: '/GetUsers'
        displayName : 'Get Users'
        name: 'GetUsers'
      }
      {
        method: 'GET'
        urlTemplate: '/GetUser'
        displayName : 'Get User'
        name: 'GetUser'
      }
    ]

  }
}
