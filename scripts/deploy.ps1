#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ParameterFile = (Join-Path $PSScriptRoot '../infra/environments/lab.bicepparam'),
  [Parameter(Mandatory)]
  [string]$SubscriptionId,
  [string]$DeploymentLocation = 'eastus2',
  [string]$DeploymentName = 'azure-secure-hub-spoke'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI with Bicep support is required.' }
$context = & az account show --query '{id:id,name:name,tenantId:tenantId}' --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $context) { throw 'Azure CLI authentication is required.' }
if ($context.id -ne $SubscriptionId) {
  throw 'The active subscription does not match SubscriptionId. Select it explicitly before continuing.'
}

Write-Information "Subscription: $($context.name) ($($context.id))" -InformationAction Continue
Write-Information "Parameter file: $ParameterFile" -InformationAction Continue
& (Join-Path $PSScriptRoot 'validate.ps1') -ParameterFile $ParameterFile -SubscriptionId $SubscriptionId -DeploymentLocation $DeploymentLocation

Write-Information 'Previewing changes with Azure Resource Manager what-if' -InformationAction Continue
& az deployment sub what-if --name $DeploymentName --location $DeploymentLocation --parameters $ParameterFile
if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

$confirmation = Read-Host 'Type DEPLOY to apply this exact plan'
if ($confirmation -cne 'DEPLOY') {
  Write-Information 'Deployment cancelled.' -InformationAction Continue
  return
}

& az deployment sub create --name $DeploymentName --location $DeploymentLocation --parameters $ParameterFile --only-show-errors --output json
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }
Write-Information 'Deployment completed. Run live validation, capture sanitized evidence, and clean up temporary resources.' -InformationAction Continue
