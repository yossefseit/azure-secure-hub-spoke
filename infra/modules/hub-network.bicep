targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Azure region.')
param location string

@description('Hub VNet address space.')
param addressSpace string

@description('Management subnet prefix.')
param managementSubnetPrefix string

@description('Shared services subnet prefix.')
param sharedServicesSubnetPrefix string

@description('Resource tags.')
param tags object

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${baseName}-hub-management'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          description: 'Explicitly block unsolicited internet traffic.'
        }
      }
    ]
  }
}

resource sharedServicesNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${baseName}-hub-shared'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetDns'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          description: 'Reserved for a future DNS resolver or forwarding service.'
        }
      }
      {
        name: 'DenyOtherVnetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          description: 'Deny lateral traffic not explicitly allowed above.'
        }
      }
    ]
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${baseName}-hub'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
  }
}

resource managementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'snet-management'
  properties: {
    addressPrefix: managementSubnetPrefix
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: managementNsg.id
    }
  }
}

resource sharedServicesSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'snet-shared-services'
  properties: {
    addressPrefix: sharedServicesSubnetPrefix
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: sharedServicesNsg.id
    }
  }
}

output vnetId string = hubVnet.id
output vnetName string = hubVnet.name
output managementSubnetId string = managementSubnet.id
output sharedServicesSubnetId string = sharedServicesSubnet.id

