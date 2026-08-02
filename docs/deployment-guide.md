# Deployment guide

## Status

The Bicep and scripts are **implemented** and can be **locally validated**. Resource Manager validation, `what-if`, deployment, and runtime checks **require a live Azure subscription**. Do not convert expected results into passed evidence.

## Prerequisites

- Azure subscription you own or are authorized to use
- Azure CLI with Bicep support
- PowerShell 7 for the `.ps1` workflow or Bash for the `.sh` workflow
- permission to create subscription deployments, resource groups, and contained resources
- a reviewed Azure budget and a deployment window short enough to remain below USD 5

Authenticate, explicitly select the subscription yourself, and inspect the context:

```bash
az login
az account set --subscription '<authorized-subscription-id>'
az account show --query '{name:name,id:id,tenantId:tenantId}' --output table
```

Never publish this output without redacting subscription and tenant identifiers.

## Parameters

Edit or copy `infra/environments/lab.bicepparam`. The `location` parameter controls resource location. `DEPLOYMENT_LOCATION` controls only where Azure stores the subscription deployment record.

Keep these cost options disabled unless their validation window is scheduled:

```bicep
param deployTestVm = false
param enableVnetFlowLogs = false
```

## Validate and preview

PowerShell:

```powershell
$env:AZURE_SUBSCRIPTION_ID = '<authorized-subscription-id>'
./scripts/validate.ps1 -SubscriptionId $env:AZURE_SUBSCRIPTION_ID
./scripts/deploy.ps1 -SubscriptionId $env:AZURE_SUBSCRIPTION_ID
```

Bash:

```bash
export AZURE_SUBSCRIPTION_ID='<authorized-subscription-id>'
./scripts/validate.sh
./scripts/deploy.sh
```

Both deployment paths run lint, compilation, authenticated validation, and `what-if`, then require the exact confirmation `DEPLOY`.

## Required pre-deployment review

Stop if `what-if` includes an unrelated resource group, role assignment, public IP, premium gateway, Firewall, Bastion, NAT Gateway, or deletion. Confirm the expected three project resource groups and review Azure Policy results before applying.

## Expected outputs

- three project resource-group names
- hub, app-spoke, and data-spoke VNet IDs
- private storage account name and Blob FQDN
- Log Analytics workspace name
- optional VM name (empty by default)

See [testing](testing.md) for runtime assertions and [cleanup](cleanup.md) for the ownership-verified teardown.
