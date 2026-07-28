using '../main.bicep'

param prefix = 'ashs'
param environment = 'lab'
param location = 'eastus2'

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

