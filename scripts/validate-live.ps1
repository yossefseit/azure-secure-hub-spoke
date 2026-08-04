#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$SubscriptionId,
  [string]$DeploymentName = 'azure-secure-hub-spoke'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI is required.' }

function Assert-Equal {
  param([string]$Label, $Actual, $Expected)
  if ($Actual -ne $Expected) { throw "$Label failed. Expected '$Expected'; observed '$Actual'." }
  Write-Information "PASS: $Label" -InformationAction Continue
}

function Assert-NotEmpty {
  param([string]$Label, $Actual)
  if ([string]::IsNullOrWhiteSpace([string]$Actual)) { throw "$Label failed; no value was returned." }
  Write-Information "PASS: $Label" -InformationAction Continue
}

$context = & az account show --query '{id:id,name:name,tenantId:tenantId}' --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $context) { throw 'Azure CLI authentication is required.' }
Assert-Equal 'active subscription' $context.id $SubscriptionId

$deployment = & az deployment sub show --name $DeploymentName --query properties --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $deployment) { throw "Deployment metadata was not found for $DeploymentName." }
$outputs = $deployment.outputs
$parameters = $deployment.parameters

$networkRg = $outputs.networkResourceGroupName.value
$workloadRg = $outputs.workloadResourceGroupName.value
$monitoringRg = $outputs.monitoringResourceGroupName.value
$deployedPrefix = $parameters.prefix.value
$deployedEnvironment = $parameters.environment.value
Assert-NotEmpty 'network resource-group output' $networkRg
Assert-NotEmpty 'workload resource-group output' $workloadRg
Assert-NotEmpty 'monitoring resource-group output' $monitoringRg
Assert-NotEmpty 'deployed prefix parameter' $deployedPrefix
Assert-NotEmpty 'deployed environment parameter' $deployedEnvironment
$baseName = "$deployedPrefix-$deployedEnvironment"

$vnets = @(
  @{
    Name = "vnet-$baseName-hub"
    Address = $parameters.hubAddressSpace.value
    RequireRouteTable = $false
    Subnets = @{
      'snet-management' = $parameters.hubManagementSubnetPrefix.value
      'snet-shared-services' = $parameters.hubSharedServicesSubnetPrefix.value
    }
  },
  @{
    Name = "vnet-$baseName-app"
    Address = $parameters.appSpokeAddressSpace.value
    RequireRouteTable = $true
    Subnets = @{
      'snet-workload' = $parameters.appWorkloadSubnetPrefix.value
      'snet-private-endpoints' = $parameters.appPrivateEndpointSubnetPrefix.value
    }
  },
  @{
    Name = "vnet-$baseName-data"
    Address = $parameters.dataSpokeAddressSpace.value
    RequireRouteTable = $true
    Subnets = @{
      'snet-workload' = $parameters.dataWorkloadSubnetPrefix.value
      'snet-private-endpoints' = $parameters.dataPrivateEndpointSubnetPrefix.value
    }
  }
)
foreach ($vnet in $vnets) {
  $actual = & az network vnet show --resource-group $networkRg --name $vnet.Name --output json | ConvertFrom-Json
  Assert-Equal "$($vnet.Name) address space" $actual.addressSpace.addressPrefixes[0] $vnet.Address
  Assert-Equal "$($vnet.Name) subnet count" $actual.subnets.Count $vnet.Subnets.Count
  foreach ($subnetName in $vnet.Subnets.Keys) {
    $matchingSubnets = @($actual.subnets | Where-Object name -EQ $subnetName)
    Assert-Equal "$($vnet.Name)/$subnetName count" $matchingSubnets.Count 1
    $subnet = $matchingSubnets[0]
    Assert-Equal "$($vnet.Name)/$subnetName address prefix" $subnet.addressPrefix $vnet.Subnets[$subnetName]
    Assert-NotEmpty "$($vnet.Name)/$($subnet.name) NSG association" $subnet.networkSecurityGroup.id
    if ($vnet.RequireRouteTable) {
      Assert-NotEmpty "$($vnet.Name)/$($subnet.name) route-table association" $subnet.routeTable.id
    }
  }
}

$peeringStates = @(& az network vnet peering list --resource-group $networkRg --vnet-name "vnet-$baseName-hub" --query '[].peeringState' --output tsv)
Assert-Equal 'hub peering count' $peeringStates.Count 2
foreach ($state in $peeringStates) { Assert-Equal 'hub peering state' $state 'Connected' }

$nsgCount = & az network nsg list --resource-group $networkRg --query 'length(@)' --output tsv
Assert-Equal 'network security-group count' $nsgCount 6
$routeTableCount = & az network route-table list --resource-group $networkRg --query 'length(@)' --output tsv
Assert-Equal 'route-table count' $routeTableCount 2
$asgCount = & az network asg list --resource-group $networkRg --query 'length(@)' --output tsv
Assert-Equal 'application security-group count' $asgCount 2

$storageName = $outputs.privateStorageAccountName.value
$storage = & az storage account show --resource-group $workloadRg --name $storageName --output json | ConvertFrom-Json
Assert-Equal 'storage public network access' $storage.publicNetworkAccess 'Disabled'
Assert-Equal 'storage shared-key access' $storage.allowSharedKeyAccess $false

$privateEndpointState = & az network private-endpoint show --resource-group $workloadRg --name "pep-$baseName-blob" --query 'privateLinkServiceConnections[0].privateLinkServiceConnectionState.status' --output tsv
Assert-Equal 'private endpoint approval' $privateEndpointState 'Approved'

$privateDnsZoneName = $outputs.privateDnsZoneName.value
Assert-NotEmpty 'private DNS zone output' $privateDnsZoneName
$dnsRecordCount = & az network private-dns record-set a list --resource-group $networkRg --zone-name $privateDnsZoneName --query 'length(@)' --output tsv
if ([int]$dnsRecordCount -lt 1) { throw 'Private DNS A record check failed.' }
Write-Information 'PASS: private DNS A record exists' -InformationAction Continue

$workspaceName = $outputs.logAnalyticsWorkspaceName.value
$workspaceId = & az monitor log-analytics workspace show --resource-group $monitoringRg --workspace-name $workspaceName --query id --output tsv
Assert-NotEmpty 'Log Analytics workspace' $workspaceId

$blobServiceId = "$($storage.id)/blobServices/default"
$diagnosticWorkspaceId = & az monitor diagnostic-settings list --resource $blobServiceId --query 'value[0].workspaceId' --output tsv
Assert-Equal 'Blob diagnostic workspace linkage' $diagnosticWorkspaceId $workspaceId

$publicIpCount = & az network public-ip list --query "length([?tags.project=='azure-secure-hub-spoke' && tags.environment=='$deployedEnvironment'])" --output tsv
Assert-Equal 'project public IP count' $publicIpCount 0

Write-Information 'All live Azure configuration checks passed. Run the private connectivity test separately when the optional VM is enabled.' -InformationAction Continue
