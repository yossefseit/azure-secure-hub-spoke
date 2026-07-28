#!/usr/bin/env bash
set -euo pipefail

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-azure-secure-hub-spoke}"

if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  echo "Set AZURE_SUBSCRIPTION_ID to the authorized deployment subscription." >&2
  exit 1
fi

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"

WORKLOAD_RESOURCE_GROUP="$(
  az deployment sub show \
    --name "${DEPLOYMENT_NAME}" \
    --query properties.outputs.workloadResourceGroupName.value \
    --output tsv
)"
TEST_VM_NAME="$(
  az deployment sub show \
    --name "${DEPLOYMENT_NAME}" \
    --query properties.outputs.testVmName.value \
    --output tsv
)"
BLOB_FQDN="$(
  az deployment sub show \
    --name "${DEPLOYMENT_NAME}" \
    --query properties.outputs.privateBlobEndpointFqdn.value \
    --output tsv
)"

if [[ -z "${TEST_VM_NAME}" ]]; then
  echo "The optional test VM is not deployed. Set deployTestVm=true temporarily." >&2
  exit 1
fi

echo "Validating private DNS and HTTPS reachability from ${TEST_VM_NAME}"
az vm run-command invoke \
  --resource-group "${WORKLOAD_RESOURCE_GROUP}" \
  --name "${TEST_VM_NAME}" \
  --command-id RunShellScript \
  --scripts \
    "set -e" \
    "getent ahostsv4 '${BLOB_FQDN}'" \
    "status=\$(curl --connect-timeout 10 --silent --show-error --output /dev/null --write-out '%{http_code}' 'https://${BLOB_FQDN}/')" \
    "echo \"Blob endpoint HTTP status: \${status} (authentication failure is expected; network failure is not)\"" \
  --query value[0].message \
  --output tsv

