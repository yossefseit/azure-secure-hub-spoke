targetScope = 'resourceGroup'

@description('Azure Private DNS zone name.')
param zoneName string

@description('VNets to link to the private DNS zone.')
param linkedVnets array

@description('Resource tags.')
param tags object

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: 'global'
  tags: tags
}

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for linkedVnet in linkedVnets: {
  parent: privateDnsZone
  name: linkedVnet.name
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: linkedVnet.id
    }
  }
}]

output zoneId string = privateDnsZone.id
output zoneName string = privateDnsZone.name

