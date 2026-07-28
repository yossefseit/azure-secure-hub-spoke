targetScope = 'resourceGroup'

@description('Base resource name.')
param baseName string

@description('Azure region.')
param location string

@description('Optional email receiver for the action group.')
param alertEmailAddress string = ''

@description('Resource tags.')
param tags object

var compactBaseName = replace(baseName, '-', '')
var diagnosticsStorageName = take(toLower('stdiag${compactBaseName}${uniqueString(subscription().id, resourceGroup().id)}'), 24)
var emailReceivers = empty(alertEmailAddress) ? [] : [
  {
    name: 'portfolio-owner'
    emailAddress: alertEmailAddress
    useCommonAlertSchema: true
  }
]

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${baseName}'
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${baseName}-operations'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    groupShortName: take(replace(baseName, '-', ''), 12)
    emailReceivers: emailReceivers
    smsReceivers: []
    webhookReceivers: []
    azureAppPushReceivers: []
    azureFunctionReceivers: []
    automationRunbookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    logicAppReceivers: []
    voiceReceivers: []
    armRoleReceivers: []
  }
}

resource diagnosticsStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: diagnosticsStorageName
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
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
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
      }
    }
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
output actionGroupId string = actionGroup.id
output diagnosticsStorageAccountId string = diagnosticsStorage.id
output diagnosticsStorageAccountName string = diagnosticsStorage.name
