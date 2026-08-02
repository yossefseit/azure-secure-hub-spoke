targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Azure region.')
param location string

@description('Subnet ID for the storage private endpoint.')
param privateEndpointSubnetId string

@description('Private DNS zone ID for Blob Storage.')
param privateDnsZoneId string

@description('Log Analytics workspace resource ID for Blob data-plane diagnostics.')
param logAnalyticsWorkspaceId string

@description('Resource tags.')
param tags object

var compactBaseName = replace(baseName, '-', '')
var storageAccountName = take(toLower('st${compactBaseName}${uniqueString(subscription().id, resourceGroup().id)}'), 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: true
      retentionInDays: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

resource labContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: 'private-lab-data'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'private-connectivity-validation'
    }
  }
}

// The latest resource-specific diagnostic settings API remains this preview version.
#disable-next-line use-recent-api-versions
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-blob-logs-to-workspace'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-10-01' = {
  name: 'pep-${baseName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
          requestMessage: 'Private access for the secure hub-spoke lab.'
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-10-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output containerName string = labContainer.name
output privateEndpointId string = privateEndpoint.id
output blobEndpointFqdn string = '${storageAccount.name}.blob.${environment().suffixes.storage}'
