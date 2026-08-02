#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$SubscriptionId,
  [ValidatePattern('^[a-z0-9]{3,8}$')]
  [string]$Prefix = 'ashs',
  [ValidateSet('lab', 'dev', 'test')]
  [string]$Environment = 'lab',
  [string]$NetworkWatcherResourceGroup = 'NetworkWatcherRG'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI is required.' }
$context = & az account show --query '{id:id,name:name,tenantId:tenantId}' --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $context) { throw 'Azure CLI authentication is required.' }
if ($context.id -ne $SubscriptionId) {
  throw 'The active subscription does not match SubscriptionId. Select it explicitly before cleanup.'
}

$baseName = "$Prefix-$Environment"
$resourceGroups = @(
  "rg-$baseName-network",
  "rg-$baseName-workload",
  "rg-$baseName-monitoring"
)

Write-Information "Subscription: $($context.name) ($($context.id))" -InformationAction Continue
Write-Information 'Resource groups proposed for deletion:' -InformationAction Continue
$resourceGroups | ForEach-Object { Write-Information "  $_" -InformationAction Continue }

foreach ($resourceGroup in $resourceGroups) {
  $exists = & az group exists --name $resourceGroup
  if ($exists -ne 'true') { continue }

  $group = & az group show --name $resourceGroup --output json | ConvertFrom-Json
  if ($group.tags.project -ne 'azure-secure-hub-spoke' -or $group.tags.managedBy -ne 'bicep' -or $group.tags.environment -ne $Environment) {
    throw "Ownership verification failed for $resourceGroup."
  }

  $unowned = @(& az resource list --resource-group $resourceGroup --query "[?tags.project!='azure-secure-hub-spoke' || tags.managedBy!='bicep'].id" --output tsv)
  if ($unowned.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace(($unowned -join ''))) {
    throw "Unowned resources exist in $resourceGroup; cleanup stopped."
  }
}

$confirmation = Read-Host "Type DELETE $baseName to continue"
if ($confirmation -cne "DELETE $baseName") {
  Write-Information 'Cleanup cancelled.' -InformationAction Continue
  return
}

if ((& az group exists --name $NetworkWatcherResourceGroup) -eq 'true') {
  $flowLogIds = @(& az resource list --resource-group $NetworkWatcherResourceGroup --resource-type 'Microsoft.Network/networkWatchers/flowLogs' --query "[?starts_with(name, 'flow-$baseName-')].id" --output tsv)
  foreach ($flowLogId in $flowLogIds) {
    if (-not [string]::IsNullOrWhiteSpace($flowLogId)) {
      & az resource delete --ids $flowLogId
      if ($LASTEXITCODE -ne 0) { throw "Failed to delete flow log $flowLogId." }
    }
  }
}

foreach ($resourceGroup in $resourceGroups) {
  if ((& az group exists --name $resourceGroup) -eq 'true') {
    & az group delete --name $resourceGroup --yes
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete $resourceGroup." }
  }
}

Write-Information 'Project-owned resources deleted.' -InformationAction Continue
