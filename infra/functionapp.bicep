@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

param location string = resourceGroup().location

var storageAccountName = uniqueString(resourceGroup().id, environmentName, 'sa')

param vnetRouteAllEnabled bool = false

@description('The built-in runtime stack to be used for a Linux-based Azure Function. This value is ignore if a Windows-based Azure Function hosting plan is used. Get the full list by executing the "az webapp list-runtimes --linux" command.')
param linuxRuntime string = 'dotnet-isolated|8.0'

@description('The id of the virtual network for virtual network integration.')
param virtualNetworkId string

param azureFunctionAppName string = 'TestFunction'

@secure()
param subnetAppServiceIntegrationId string

@secure()
param subnetPrivateEndpointId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
  }
}

resource service 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: service
  name: 'fileshare'
}

// resource storageAccountFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
//   name: '${storageAccount.name}/default/${fileShareName}'
// }

resource azureFunctionPlan 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: 'plan-${environmentName}'
  location: location
  kind: 'elastic'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
  }
  properties: {
    maximumElasticWorkerCount: 20
    reserved: true
  }
}

resource azureFunction 'Microsoft.Web/sites@2020-12-01' = {
  name: azureFunctionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    httpsOnly: false
    serverFarmId: azureFunctionPlan.id
    reserved: true
    virtualNetworkSubnetId: subnetAppServiceIntegrationId
    siteConfig: {
      vnetRouteAllEnabled: vnetRouteAllEnabled
      functionsRuntimeScaleMonitoringEnabled: true
      linuxFxVersion: linuxRuntime
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

resource functionPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: 'pe-${azureFunctionAppName}-sites'
  location: location
  properties: {
    subnet: {
      id: subnetPrivateEndpointId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${azureFunctionAppName}-sites'
        properties: {
          privateLinkServiceId: azureFunction.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource functionPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

resource functionPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: functionPrivateDnsZone
  name: '${functionPrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource functionPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  parent: functionPrivateEndpoint
  name: 'functionPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: functionPrivateDnsZone.id
        }
      }
    ]
  }
}

output azureFunctionTenantId string = azureFunction.identity.tenantId
output azureFunctionPrincipalId string = azureFunction.identity.principalId
output azureFunctionId string = azureFunction.id
