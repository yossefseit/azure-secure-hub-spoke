#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ParameterFile = (Join-Path $PSScriptRoot '../infra/environments/lab.bicepparam'),
  [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
  [string]$DeploymentLocation = 'eastus2'
)

$ErrorActionPreference = 'Stop'
$templateFile = Join-Path $PSScriptRoot '../infra/main.bicep'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI with Bicep support is required.'
}

Write-Information "Linting $templateFile" -InformationAction Continue
& az bicep lint --file $templateFile
if ($LASTEXITCODE -ne 0) { throw 'Bicep lint failed.' }

Write-Information "Compiling $templateFile" -InformationAction Continue
& az bicep build --file $templateFile --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
  Write-Warning 'AZURE_SUBSCRIPTION_ID is unset; authenticated Resource Manager validation was skipped.'
  return
}

$context = & az account show --query '{id:id,name:name,tenantId:tenantId}' --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $context) { throw 'Azure CLI authentication is required.' }
if ($context.id -ne $SubscriptionId) {
  throw 'The active subscription does not match SubscriptionId. Select it explicitly before continuing.'
}

Write-Information "Subscription: $($context.name) ($($context.id))" -InformationAction Continue
Write-Information 'Running subscription-level Resource Manager validation' -InformationAction Continue
& az deployment sub validate --location $DeploymentLocation --parameters $ParameterFile --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Resource Manager validation failed.' }
