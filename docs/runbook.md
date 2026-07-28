# Deployment and operations runbook

## 1. Preflight

Confirm:

- the subscription is personal or explicitly authorized for the lab
- you have permission to create subscription deployments and resource groups
- the selected region supports the planned resources
- a budget and alert already exist
- Azure CLI is authenticated to the intended tenant

Set the exact subscription:

```bash
export AZURE_SUBSCRIPTION_ID="<authorized-subscription-id>"
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
az account show --query '{name:name,id:id,tenantId:tenantId}' --output table
```

Do not copy the output into public evidence without redaction.

## 2. Offline validation

```bash
./scripts/validate.sh
```

The GitHub Actions workflow runs the same lint and compilation checks without Azure credentials.

## 3. Authenticated validation and deployment

```bash
export AZURE_SUBSCRIPTION_ID="<authorized-subscription-id>"
./scripts/deploy.sh
```

Review the entire `what-if` result. Stop if it includes an unexpected resource group, public IP, expensive gateway, Firewall, Bastion, or broad role assignment.

## 4. Runtime checks

Confirm:

- all peerings show `Connected`
- no NIC has a public IP
- the storage firewall reports public network access disabled
- the Blob private endpoint connection is approved
- the Blob FQDN resolves to a private address from the app VNet
- direct unauthenticated HTTPS reaches the private endpoint but is denied at the data plane

For the final two checks, temporarily deploy the test VM and run:

```bash
./scripts/test-connectivity.sh
```

An HTTP `400` or `403` proves the endpoint responded while rejecting the anonymous request. A timeout or public IP resolution is a failed network test.

## 5. Evidence capture

Save only redacted screenshots or text:

- successful workflow run
- `what-if` resource summary
- resource-group and topology overview
- peering state
- private endpoint state
- private DNS result
- connectivity result

Update `docs/validation.md` with dates and actual outcomes. Do not mark a test passed before it runs.

## 6. Teardown

```bash
PREFIX="ashs" ENVIRONMENT="lab" ./scripts/destroy.sh
```

Confirm all three resource groups are gone:

```bash
az group list \
  --query "[?starts_with(name, 'rg-ashs-lab-')].name" \
  --output table
```

Review costs again after usage data is processed.

