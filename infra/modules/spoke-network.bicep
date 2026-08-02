targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Short spoke role, such as app or data.')
param spokeName string

@description('Azure region.')
param location string

@description('Spoke VNet address space.')
param addressSpace string

@description('Workload subnet prefix.')
param workloadSubnetPrefix string

@description('Private endpoint subnet prefix.')
param privateEndpointSubnetPrefix string

@description('CIDR allowed to reach the workload and private endpoint over approved ports.')
param allowedSourcePrefix string

@description('Destination ports allowed from allowedSourcePrefix.')
param allowedDestinationPorts array

@description('Other spoke CIDR intentionally blackholed to preserve baseline spoke isolation if routing changes later.')
param blockedSpokePrefix string

@description('Allow temporary platform default outbound access for a validation workload. Keep false for steady state.')
param allowWorkloadDefaultOutboundAccess bool = false

@description('Resource tags.')
param tags object

resource workloadApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2025-05-01' = {
  name: 'asg-${baseName}-${spokeName}-workload'
  location: location
  tags: tags
}

resource spokeRouteTable 'Microsoft.Network/routeTables@2025-05-01' = {
  name: 'rt-${baseName}-${spokeName}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'block-unintended-${spokeName}-cross-spoke'
        properties: {
          addressPrefix: blockedSpokePrefix
          nextHopType: 'None'
        }
      }
    ]
  }
}

resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2024-10-01' = {
  name: 'nsg-${baseName}-${spokeName}-workload'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowApprovedSource'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: allowedDestinationPorts
          sourceAddressPrefix: allowedSourcePrefix
          destinationAddressPrefix: '*'
          description: 'Allow only approved workload traffic.'
        }
      }
      {
        name: 'AllowWorkloadAsgHttpsOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceApplicationSecurityGroups: [
            {
              id: workloadApplicationSecurityGroup.id
            }
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          description: 'Allow ASG-identified workloads to use HTTPS within connected virtual networks.'
        }
      }
      {
        name: 'DenyOtherVnetOutbound'
        properties: {
          priority: 4000
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          description: 'Block other lateral traffic from the workload subnet.'
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
          description: 'Prevent unapproved lateral movement through peering.'
        }
      }
    ]
  }
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2024-10-01' = {
  name: 'nsg-${baseName}-${spokeName}-private-endpoints'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowApprovedSourceHttps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: allowedSourcePrefix
          destinationAddressPrefix: '*'
          description: 'Allow HTTPS to private endpoints from the approved source range.'
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
          description: 'Block other lateral traffic to private endpoints.'
        }
      }
    ]
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-10-01' = {
  name: 'vnet-${baseName}-${spokeName}'
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

resource workloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-10-01' = {
  parent: spokeVnet
  name: 'snet-workload'
  properties: {
    addressPrefix: workloadSubnetPrefix
    defaultOutboundAccess: allowWorkloadDefaultOutboundAccess
    networkSecurityGroup: {
      id: workloadNsg.id
    }
    routeTable: {
      id: spokeRouteTable.id
    }
  }
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-10-01' = {
  parent: spokeVnet
  name: 'snet-private-endpoints'
  properties: {
    addressPrefix: privateEndpointSubnetPrefix
    defaultOutboundAccess: false
    privateEndpointNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: privateEndpointNsg.id
    }
    routeTable: {
      id: spokeRouteTable.id
    }
  }
}

output vnetId string = spokeVnet.id
output vnetName string = spokeVnet.name
output workloadSubnetId string = workloadSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output workloadApplicationSecurityGroupId string = workloadApplicationSecurityGroup.id
output routeTableId string = spokeRouteTable.id
