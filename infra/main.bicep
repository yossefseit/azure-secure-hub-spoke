targetScope = 'subscription'

metadata name = 'Azure Secure Hub-Spoke'
metadata description = 'A private-by-default hub-spoke network foundation with centralized DNS, monitoring, and an optional ephemeral validation VM.'

@description('Short lowercase project prefix used in resource names.')
@minLength(3)
@maxLength(8)
param prefix string = 'ashs'

@description('Deployment environment.')
@allowed([
  'lab'
  'dev'
  'test'
])
param environment string = 'lab'

@description('Primary Azure region.')
param location string = 'eastus2'

@description('Hub VNet address space.')
param hubAddressSpace string = '10.0.0.0/16'

@description('Application spoke VNet address space.')
param appSpokeAddressSpace string = '10.10.0.0/16'

@description('Data spoke VNet address space.')
param dataSpokeAddressSpace string = '10.20.0.0/16'

@description('Optional tags merged with the project tags.')
param additionalTags object = {}

@description('Deploy a temporary private VM for DNS and connectivity validation. Keep false unless actively testing.')
param deployTestVm bool = false

@description('SSH public key for the optional test VM. Required only when deployTestVm is true.')
param testVmSshPublicKey string = ''

@description('Enable VNet flow logs. Requires an existing Network Watcher in the target region.')
param enableVnetFlowLogs bool = false

@description('Resource group containing the existing regional Network Watcher.')
param networkWatcherResourceGroupName string = 'NetworkWatcherRG'

@description('Existing Network Watcher name, normally NetworkWatcher_<region>.')
param networkWatcherName string = 'NetworkWatcher_${location}'

@description('Optional alert email. Leave empty to create the action group without an email receiver.')
param alertEmailAddress string = ''

var baseName = toLower('${prefix}-${environment}')
var blobPrivateDnsZoneName = 'privatelink.blob.${az.environment().suffixes.storage}'
var commonTags = union(additionalTags, {
  project: 'azure-secure-hub-spoke'
  environment: environment
  managedBy: 'bicep'
  repository: 'github.com/yossefseit/azure-secure-hub-spoke'
})

var networkResourceGroupName = 'rg-${baseName}-network'
var workloadResourceGroupName = 'rg-${baseName}-workload'
var monitoringResourceGroupName = 'rg-${baseName}-monitoring'

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: networkResourceGroupName
  location: location
  tags: commonTags
}

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: workloadResourceGroupName
  location: location
  tags: commonTags
}

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: monitoringResourceGroupName
  location: location
  tags: commonTags
}

module hubNetwork './modules/hub-network.bicep' = {
  name: 'deploy-hub-network'
  scope: networkResourceGroup
  params: {
    baseName: baseName
    location: location
    addressSpace: hubAddressSpace
    managementSubnetPrefix: '10.0.1.0/24'
    sharedServicesSubnetPrefix: '10.0.2.0/24'
    tags: commonTags
  }
}

module appSpoke './modules/spoke-network.bicep' = {
  name: 'deploy-app-spoke'
  scope: networkResourceGroup
  params: {
    baseName: baseName
    spokeName: 'app'
    location: location
    addressSpace: appSpokeAddressSpace
    workloadSubnetPrefix: '10.10.1.0/24'
    privateEndpointSubnetPrefix: '10.10.2.0/24'
    allowedSourcePrefix: '10.10.0.0/16'
    allowedDestinationPorts: [
      '443'
    ]
    blockedSpokePrefix: dataSpokeAddressSpace
    allowWorkloadDefaultOutboundAccess: deployTestVm
    tags: commonTags
  }
}

module dataSpoke './modules/spoke-network.bicep' = {
  name: 'deploy-data-spoke'
  scope: networkResourceGroup
  params: {
    baseName: baseName
    spokeName: 'data'
    location: location
    addressSpace: dataSpokeAddressSpace
    workloadSubnetPrefix: '10.20.1.0/24'
    privateEndpointSubnetPrefix: '10.20.2.0/24'
    allowedSourcePrefix: '10.0.0.0/16'
    allowedDestinationPorts: [
      '443'
    ]
    blockedSpokePrefix: appSpokeAddressSpace
    allowWorkloadDefaultOutboundAccess: false
    tags: commonTags
  }
}

module hubToAppPeering './modules/vnet-peering.bicep' = {
  name: 'peer-hub-to-app'
  scope: networkResourceGroup
  params: {
    localVnetName: hubNetwork.outputs.vnetName
    remoteVnetId: appSpoke.outputs.vnetId
    peeringName: 'peer-hub-to-app'
    allowForwardedTraffic: false
  }
}

module appToHubPeering './modules/vnet-peering.bicep' = {
  name: 'peer-app-to-hub'
  scope: networkResourceGroup
  params: {
    localVnetName: appSpoke.outputs.vnetName
    remoteVnetId: hubNetwork.outputs.vnetId
    peeringName: 'peer-app-to-hub'
    allowForwardedTraffic: false
  }
}

module hubToDataPeering './modules/vnet-peering.bicep' = {
  name: 'peer-hub-to-data'
  scope: networkResourceGroup
  params: {
    localVnetName: hubNetwork.outputs.vnetName
    remoteVnetId: dataSpoke.outputs.vnetId
    peeringName: 'peer-hub-to-data'
    allowForwardedTraffic: false
  }
}

module dataToHubPeering './modules/vnet-peering.bicep' = {
  name: 'peer-data-to-hub'
  scope: networkResourceGroup
  params: {
    localVnetName: dataSpoke.outputs.vnetName
    remoteVnetId: hubNetwork.outputs.vnetId
    peeringName: 'peer-data-to-hub'
    allowForwardedTraffic: false
  }
}

module privateDns './modules/private-dns.bicep' = {
  name: 'deploy-private-dns'
  scope: networkResourceGroup
  params: {
    zoneName: blobPrivateDnsZoneName
    linkedVnets: [
      {
        name: 'link-hub'
        id: hubNetwork.outputs.vnetId
      }
      {
        name: 'link-app'
        id: appSpoke.outputs.vnetId
      }
    ]
    tags: commonTags
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: monitoringResourceGroup
  params: {
    baseName: baseName
    location: location
    alertEmailAddress: alertEmailAddress
    monitoredResourceGroupNames: [
      networkResourceGroupName
      workloadResourceGroupName
      monitoringResourceGroupName
    ]
    tags: commonTags
  }
}

module privateStorage './modules/private-storage.bicep' = {
  name: 'deploy-private-storage'
  scope: workloadResourceGroup
  params: {
    baseName: baseName
    location: location
    privateEndpointSubnetId: appSpoke.outputs.privateEndpointSubnetId
    privateDnsZoneId: privateDns.outputs.zoneId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: commonTags
  }
}

module testVm './modules/test-vm.bicep' = if (deployTestVm) {
  name: 'deploy-ephemeral-test-vm'
  scope: workloadResourceGroup
  params: {
    baseName: baseName
    location: location
    subnetId: appSpoke.outputs.workloadSubnetId
    applicationSecurityGroupId: appSpoke.outputs.workloadApplicationSecurityGroupId
    sshPublicKey: testVmSshPublicKey
    tags: union(commonTags, {
      lifecycle: 'ephemeral'
    })
  }
}

module vnetFlowLogs './modules/vnet-flow-logs.bicep' = if (enableVnetFlowLogs) {
  name: 'deploy-vnet-flow-logs'
  scope: resourceGroup(networkWatcherResourceGroupName)
  params: {
    baseName: baseName
    location: location
    networkWatcherName: networkWatcherName
    targetVnetIds: [
      hubNetwork.outputs.vnetId
      appSpoke.outputs.vnetId
      dataSpoke.outputs.vnetId
    ]
    storageAccountId: monitoring.outputs.diagnosticsStorageAccountId
  }
}

output networkResourceGroupName string = networkResourceGroupName
output workloadResourceGroupName string = workloadResourceGroupName
output monitoringResourceGroupName string = monitoringResourceGroupName
output hubVnetId string = hubNetwork.outputs.vnetId
output appSpokeVnetId string = appSpoke.outputs.vnetId
output dataSpokeVnetId string = dataSpoke.outputs.vnetId
output privateStorageAccountName string = privateStorage.outputs.storageAccountName
output privateBlobEndpointFqdn string = privateStorage.outputs.blobEndpointFqdn
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName
output testVmName string = deployTestVm ? testVm!.outputs.vmName : ''
