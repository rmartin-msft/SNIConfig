@description('The id of the virtual network for virtual network integration.')
param jumpboxVmSubnetId string 
param jumpboxVmName string = 'jumpboxvm'
param location string = resourceGroup().location
param adminUserName string 

@secure()
param adminPassword string

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'myPublicIp'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource jumpboxNic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'jumpboxNic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: jumpboxVmSubnetId
          }
        }
      }
    ]
  }
}


resource windowsVmSchedule 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${jumpboxVmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'UTC'
    notificationSettings: {
      status: 'Disabled'
    }
    targetResourceId: windowsVM.id
  }
}

resource windowsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: jumpboxVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2_v4'
    }
    osProfile: {
      computerName: jumpboxVmName
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpboxNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
