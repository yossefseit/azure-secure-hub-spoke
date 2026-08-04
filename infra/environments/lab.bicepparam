using '../main.bicep'

param prefix = 'ashs'
param environment = 'lab'
param location = 'eastus2'

param hubAddressSpace = '10.0.0.0/16'
param hubManagementSubnetPrefix = '10.0.1.0/24'
param hubSharedServicesSubnetPrefix = '10.0.2.0/24'
param appSpokeAddressSpace = '10.10.0.0/16'
param appWorkloadSubnetPrefix = '10.10.1.0/24'
param appPrivateEndpointSubnetPrefix = '10.10.2.0/24'
param dataSpokeAddressSpace = '10.20.0.0/16'
param dataWorkloadSubnetPrefix = '10.20.1.0/24'
param dataPrivateEndpointSubnetPrefix = '10.20.2.0/24'

param deployTestVm = false
param testVmSshPublicKey = ''

param enableVnetFlowLogs = false
param networkWatcherResourceGroupName = 'NetworkWatcherRG'
param networkWatcherName = 'NetworkWatcher_eastus2'

param alertEmailAddress = ''

param additionalTags = {
  owner: 'yossef-mohammed-ali'
  purpose: 'portfolio-lab'
  costCenter: 'personal-learning'
}
