targetScope = 'resourceGroup'

@description('Existing local VNet name.')
param localVnetName string

@description('Remote VNet resource ID.')
param remoteVnetId string

@description('Peering resource name.')
param peeringName string

@description('Allow forwarded traffic from the remote VNet.')
param allowForwardedTraffic bool = false

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

output peeringId string = peering.id

