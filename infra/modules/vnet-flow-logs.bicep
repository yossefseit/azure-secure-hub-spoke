targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Azure region.')
param location string

@description('Name of an existing Network Watcher in this resource group.')
param networkWatcherName string

@description('VNet resource IDs for flow logging.')
param targetVnetIds array

@description('Storage account resource ID for raw flow logs.')
param storageAccountId string

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-10-01' existing = {
  name: networkWatcherName
}

resource flowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-10-01' = [for (targetVnetId, index) in targetVnetIds: {
  parent: networkWatcher
  name: 'flow-${baseName}-${index}'
  location: location
  properties: {
    enabled: true
    targetResourceId: targetVnetId
    storageId: storageAccountId
    format: {
      type: 'JSON'
      version: 2
    }
    retentionPolicy: {
      enabled: true
      days: 7
    }
  }
}]

output flowLogIds array = [for index in range(0, length(targetVnetIds)): flowLogs[index].id]
