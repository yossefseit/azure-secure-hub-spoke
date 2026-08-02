using '../main.bicep'

param prefix = 'ashs'
param environment = 'lab'
param location = 'eastus2'

param hubAddressSpace = '10.0.0.0/16'
param appSpokeAddressSpace = '10.10.0.0/16'
param dataSpokeAddressSpace = '10.20.0.0/16'

param deployTestVm = false
param testVmSshPublicKey = ''

param enableVnetFlowLogs = false
param networkWatcherResourceGroupName = 'NetworkWatcherRG'
param networkWatcherName = 'NetworkWatcher_eastus2'

param alertEmailAddress = ''

param additionalTags = {
  owner: 'yossef-mohamed-ali'
  purpose: 'portfolio-lab'
  costCenter: 'personal-learning'
}
