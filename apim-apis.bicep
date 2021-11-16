//REF: https://www.jeanpaulsmit.com/2020/12/bicep-deploy-apim/

param apimName string

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

resource UserApi 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: 'GetUsers'
  parent: apim
  properties: {
    path: 'users'
    displayName: 'Users API'
    serviceUrl: 'https://serverlessohapi.azurewebsites.net/api/'
  }
}

resource GetUsersAPI 'Microsoft.ApiManagement/service/apis/operations@2021-04-01-preview' = {
  name: 'GetUsers'
  parent: UserApi
  properties: {
    displayName: 'Get Users'
    method: 'GET'
    urlTemplate: '/GetUsers'
    description: 'Get all of the Ice Cream Users'
  }
}


// resource apimProduct 'Microsoft.ApiManagement/service/products@2019-12-01' = {
//   name: '${apim.name}/custom-product'
//   properties: {
//     approvalRequired: true
//     subscriptionRequired: true
//     displayName: 'Custom product'
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
