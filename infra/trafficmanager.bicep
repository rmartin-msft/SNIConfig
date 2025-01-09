resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: 'myTrafficManagerProfile'
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: 'mytrafficmanager'
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTP'
      port: 80
      path: '/'
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'myVirtualNetwork'
  location: resourceGroup().location
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
    ]
  }
}
