//REF: https://www.jeanpaulsmit.com/2020/12/bicep-deploy-apim/
//REF: https://dibranmulder.github.io/2018/12/19/Azure-API-Management-ARM-Cheatsheet/

param apimName string

param ratingsApiBaseUrl string = 'https://app-ratings-fi4a3nk4vlrka.azurewebsites.net/api'
param productsApiBaseUrl string = 'https://serverlessohapi.azurewebsites.net/api/'
param usersApiBaseUrl string = 'https://serverlessohapi.azurewebsites.net/api/'

param AppInsightsName string = ''

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = if(!empty(AppInsightsName)) {
  name: AppInsightsName
}

resource ApimLogger 'Microsoft.ApiManagement/service/loggers@2021-04-01-preview' = {
  name: 'API-Logger'
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    resourceId: AppInsights.id
    credentials: {
      'instrumentationKey': AppInsights.properties.InstrumentationKey
    }
    description: 'Application Insights telemetry from APIs'
  }
}

var ApiLoggingProperties = {
  alwaysLog: 'allErrors'
  httpCorrelationProtocol: 'Legacy'
  verbosity: 'information'
  logClientIp: true
  loggerId: ApimLogger.id
  sampling: {
    samplingType: 'fixed'
    percentage: 100
  }
}

resource UserApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: 'GetUsers'
  parent: apim
  properties: {
    path: 'users'
    displayName: 'Users API'
    serviceUrl: usersApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: false
  }
}

resource UserApiDiags 'Microsoft.ApiManagement/service/apis/diagnostics@2021-04-01-preview' = {
  name: 'applicationinsights'
  parent: UserApi
  properties: ApiLoggingProperties
}

resource GetUsersMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetUsers'
  parent: UserApi
  properties: {
    displayName: 'Get Users'
    method: 'GET'
    urlTemplate: '/GetUsers'
    description: 'Get all of the Ice Cream Users'
  }
}

resource GetUserMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetUser'
  parent: UserApi
  properties: {
    displayName: 'Get User'
    method: 'GET'
    urlTemplate: '/GetUser'
    description: 'Get an Ice Cream Users'
  }
}

resource ProductApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: 'ProductAPI'
  parent: apim
  properties: {
    path: 'products'
    displayName: 'Products API'
    serviceUrl: productsApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: false
  }
}

resource ProductApiDiags 'Microsoft.ApiManagement/service/apis/diagnostics@2021-04-01-preview' = {
  name: 'applicationinsights'
  parent: ProductApi
  properties: ApiLoggingProperties
}

resource GetProductsMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetProducts'
  parent: ProductApi
  properties: {
    displayName: 'Get Products'
    method: 'GET'
    urlTemplate: '/GetProducts'
    description: 'Get all of the Ice Cream Products'
  }
}

resource GetProductsCacheMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetProductsCacheDemo'
  parent: ProductApi
  properties: {
    displayName: 'Get Products cache demo'
    method: 'GET'
    urlTemplate: '/GetProducts?randomqs=true'
    description: 'Get all of the Ice Cream Products. Cachey cache cache'
  }
}

resource ProductCache 'Microsoft.ApiManagement/service/apis/operations/policies@2021-04-01-preview' = {
  name: 'policy'
  parent: GetProductsCacheMethod
  properties: {
    value: 'https://raw.githubusercontent.com/Gordonby/Snippets/master/AzureApimPolicies/CacheFor3600.xml'
    format: 'xml-link'
  }
}

resource GetProductMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetProduct'
  parent: ProductApi
  properties: {
    displayName: 'Get Product'
    method: 'GET'
    urlTemplate: '/GetProduct'
    description: 'Get an Ice Cream Products'
  }
}

resource RatingsApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: 'Ratings'
  parent: apim
  properties: {
    path: 'ratings'
    displayName: 'Ratings API'
    serviceUrl: ratingsApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: false
  }
}

resource RatingsApiDiags 'Microsoft.ApiManagement/service/apis/diagnostics@2021-04-01-preview' = {
  name: 'applicationinsights'
  parent: RatingsApi
  properties: ApiLoggingProperties
}

resource GetRatingsMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetRatings'
  parent: RatingsApi
  properties: {
    displayName: 'Get Ratings'
    method: 'GET'
    urlTemplate: '/GetRatings/{userid}'
    description: 'Get all of the ratings'
    templateParameters: [
      {
        name: 'userid'
        defaultValue: 'cc20a6fb-a91f-4192-874d-132493685376'
        type: ''
      }
    ]
  }
}

resource GetRatingMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetRating'
  parent: RatingsApi
  properties: {
    displayName: 'Get Rating'
    method: 'GET'
    urlTemplate: '/GetRating/{ratingsId}'
    description: 'Get all of the ratings'
    templateParameters: [
      {
        name: 'ratingsId'
        defaultValue: '79c2779e-dd2e-43e8-803d-ecbebed8972c'
        type: ''
      }
    ]
  }
}

resource RatingsAdminApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: 'RatingsAdmin'
  parent: apim
  properties: {
    path: 'ratingsadmin'
    displayName: 'Ratings Admin API'
    serviceUrl: ratingsApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: false
  }
}

resource CreateRatingsMethod 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'CreateRatings'
  parent: RatingsAdminApi
  properties: {
    displayName: 'Create Ratings'
    method: 'POST'
    urlTemplate: '/CreateRatings'
    description: 'Create a ratings'
  }
}

resource mobileUsers 'Microsoft.ApiManagement/service/products@2019-12-01' = {
  name: 'mobileUsers'
  parent: apim
  properties: {
    approvalRequired: true
    subscriptionRequired: true
    displayName: 'Mobile Users'
    state: 'published'
  }
}

resource InternalUsers 'Microsoft.ApiManagement/service/products@2019-12-01' = {
  name: 'internalUsers'
  parent: apim
  properties: {
    approvalRequired: true
    subscriptionRequired: true
    displayName: 'Internal Users'
    state: 'published'
  }
}

resource Partners 'Microsoft.ApiManagement/service/products@2019-12-01' = {
  name: 'ExternalPartners'
  parent: apim
  properties: {
    approvalRequired: true
    subscriptionRequired: true
    displayName: 'External Partners Users'
    state: 'published'
  }
}

module webTestGetProducts 'appinsightswebtest.bicep' = if(!empty(AppInsightsName)) {
  name: 'ApimWebTest-GetProducts'
  params: {
    Name: '${ProductApi.name}-GetProducts-Apim'
    AppInsightsName: AppInsights.name
    //I'm leaving this first() example here instead of just using apim.properties.gatewayUrl - just for reference of another way
    WebTestUrl: 'https://${first(apim.properties.hostnameConfigurations).hostName}/Products${GetProductsMethod.properties.urlTemplate}'
  }
}

module webTestGetProductsCached 'appinsightswebtest.bicep' = if(!empty(AppInsightsName)) {
  name: 'ApimWebTest-GetProductsCached'
  params: {
    Name: '${ProductApi.name}-GetProducts-ApimCached'
    AppInsightsName: AppInsights.name
    WebTestUrl: '${apim.properties.gatewayUrl}/Products${GetProductsCacheMethod.properties.urlTemplate}'
  }
}

module webTestDirectGetProducts 'appinsightswebtest.bicep' = if(!empty(AppInsightsName)) {
  name: 'DirectWebTest-GetProducts'
  params: {
    Name: '${ProductApi.name}-GetProducts-Direct'
    AppInsightsName: AppInsights.name
    WebTestUrl: '${usersApiBaseUrl}${GetProductsMethod.properties.urlTemplate}'
  }
}

module webTestGetUsers 'appinsightswebtest.bicep' = if(!empty(AppInsightsName)) {
  name: 'ApimWebTest-GetUsers'
  params: {
    Name: '${UserApi.name}-GetUsers-Apim'
    AppInsightsName: AppInsights.name
    WebTestUrl: '${apim.properties.gatewayUrl}/Users${GetUsersMethod.properties.urlTemplate}'
  }
}

module webTestDirectGetUsers 'appinsightswebtest.bicep' = if(!empty(AppInsightsName)) {
  name: 'DirectWebTest-GetUsers'
  params: {
    Name: '${UserApi.name}-GetUsers-Direct'
    AppInsightsName: AppInsights.name
    WebTestUrl: '${productsApiBaseUrl}${GetUsersMethod.properties.urlTemplate}'
  }
}

// resource PartnerRateLimit 'Microsoft.ApiManagement/service/policies@2021-04-01-preview' = {
//   name: 'ExternalPartners'
  
//   parent: apim
//   properties: {

//     approvalRequired: true
//     subscriptionRequired: true
//     displayName: 'External Partners Users'
//     state: 'published'
//   }
// }

// // Add custom policy to product
// resource apimProductPolicy 'Microsoft.ApiManagement/service/products/policies@2019-12-01' = {
//   name: '${apimProduct.name}/policy'
//   properties: {
//     format: 'rawxml'
//     value: '<policies><inbound><base /></inbound><backend><base /></backend><outbound><set-header name="Server" exists-action="delete" /><set-header name="X-Powered-By" exists-action="delete" /><set-header name="X-AspNet-Version" exists-action="delete" /><base /></outbound><on-error><base /></on-error></policies>'
//   }
// }

// resource apimUser 'Microsoft.ApiManagement/service/users@2019-12-01' = {
//   name: '${apim.name}/custom-user'
//   properties: {
//     firstName: 'Custom'
//     lastName: 'User'
//     state: 'active'
//     email: 'custom-user-email@address.com'
//   }
// }

// resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2019-12-01' = {
//   name: '${apim.name}/custom-subscription'
//   properties: {
//     displayName: 'Custom Subscription'
//     primaryKey: 'custom-primary-key-${uniqueString(resourceGroup().id)}'
//     secondaryKey: 'custom-secondary-key-${uniqueString(resourceGroup().id)}'
//     state: 'active'
//     scope: '/products/${apimProduct.id}'
//   }
// }
