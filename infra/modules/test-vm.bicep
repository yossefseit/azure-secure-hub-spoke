targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Azure region.')
param location string

@description('Private subnet resource ID.')
param subnetId string

@description('Application Security Group assigned to the validation NIC.')
param applicationSecurityGroupId string

@description('SSH public key for the test VM administrator.')
@minLength(32)
param sshPublicKey string

@description('Administrator username for the temporary test VM.')
param adminUsername string = 'azureuser'

@description('Resource tags.')
param tags object

var vmName = 'vm-${baseName}-test'
var nicName = 'nic-${baseName}-test'

resource nic 'Microsoft.Network/networkInterfaces@2024-10-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          applicationSecurityGroups: [
            {
              id: applicationSecurityGroupId
            }
          ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        ssh: {
          publicKeys: [
            {
              keyData: sshPublicKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output nicId string = nic.id
