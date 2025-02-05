targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Admin username for the jumpbox VM')
param vmAdminUsername string

@secure()
@description('Password for the admin user')
param vmAdminPassword string

// param azureFunctionAppName string = 'TestFunction'

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module virtualNet 'network.bicep' = {
  name: 'virtualNet'
  scope: resourceGroup(rg.name)
  params: {
    environmentName: environmentName 
    virtualNetworkName: 'vnet-${environmentName}'
  }
}

module azureFunction 'functionapp.bicep' = {
  name: 'azureFunctionsDeploy'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    environmentName: environmentName
    virtualNetworkId: virtualNet.outputs.virtualNetworkId
    subnetAppServiceIntegrationId: virtualNet.outputs.subnetAppServiceIntId
    subnetPrivateEndpointId: virtualNet.outputs.subnetPrivateEndpointId
    // vnetRouteAllEnabled: false
    azureFunctionAppName: uniqueString(rg.id, environmentName, 'fn')
  }
}

module jumpboxVM 'jumpbox.bicep' = {
  name: 'jumpboxVM'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    jumpboxVmSubnetId: virtualNet.outputs.subnetJumpBoxIntId
    adminUserName: vmAdminUsername
    adminPassword: vmAdminPassword
  }
}

