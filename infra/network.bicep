@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@description('The IP space to use for the subnet for private endpoints.')
param jumpBoxAddressPrefix string = '10.0.1.0/24'

@description('The IP space to use for the subnet for Azure App Service regional virtual network integration.')
param subnetAppServiceIntAddressPrefix string = '10.0.3.0/24'

@description('The IP space to use for the subnet for private endpoints.')
param subnetPrivateEndpointAddressPrefix string = '10.0.4.0/24'

@description('The name for the Azure virtual network to be created.')
param virtualNetworkName string = 'myVirtualNetwork'

param location string = resourceGroup().location


var nsgName = '${environmentName}-nsg'

@description('The service types to enable service endpoints for on the App Service integration subnet.')
param subnetAppServiceIntServiceEndpointTypes array = [ 'Microsoft.Web', 'Microsoft.KeyVault' ]


resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: '${nsgName}-pe'
  location: location
}

resource appServiceIntegrationNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: '${nsgName}-appServiceInt'
  location: location
}

resource jumpBoxNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: '${nsgName}-jumpbox'
  location: location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'jumpboxes'
        properties: {
          networkSecurityGroup: {
            id: jumpBoxNsg.id
          }
          addressPrefix: jumpBoxAddressPrefix          
        }
      }
      {
        name: 'appServiceIntegration'
        properties: {
          networkSecurityGroup: {
            id: appServiceIntegrationNsg.id
          }
          addressPrefix: subnetAppServiceIntAddressPrefix
          serviceEndpoints: [for service in subnetAppServiceIntServiceEndpointTypes: {
            service: service
            locations: [
              '*'
            ]
          }]
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'privateEndpointDelegation'
        properties: {
          networkSecurityGroup: {
            id: privateEndpointNsg.id
          }
          addressPrefix: subnetPrivateEndpointAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output virtualNetworkId string = virtualNetwork.id
output subnetJumpBoxIntId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, 'jumpboxes')
output subnetAppServiceIntId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, 'appServiceIntegration')
output subnetPrivateEndpointId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, 'privateEndpointDelegation')
