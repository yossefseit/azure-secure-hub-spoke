#!/usr/bin/env bash
set -euo pipefail

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-azure-secure-hub-spoke}"

if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  echo "Set AZURE_SUBSCRIPTION_ID to the authorized deployment subscription." >&2
  exit 1
fi

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required." >&2
  exit 1
}

ACTIVE_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
if [[ "${ACTIVE_SUBSCRIPTION_ID}" != "${AZURE_SUBSCRIPTION_ID}" ]]; then
  echo "Active Azure subscription does not match AZURE_SUBSCRIPTION_ID. Select it explicitly before testing." >&2
  exit 1
fi

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
    "resolved=\$(getent ahostsv4 '${BLOB_FQDN}' | awk 'NR == 1 { print \$1 }')" \
    "echo \"Blob endpoint resolved address: \${resolved}\"" \
    "case \"\${resolved}\" in 10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;; *) echo 'Expected an RFC1918 private address.' >&2; exit 1 ;; esac" \
    "status=\$(curl --connect-timeout 10 --silent --show-error --output /dev/null --write-out '%{http_code}' 'https://${BLOB_FQDN}/')" \
    "echo \"Blob endpoint HTTP status: \${status}\"" \
    "case \"\${status}\" in 400|401|403) ;; *) echo 'Expected an authentication/client error from the private endpoint.' >&2; exit 1 ;; esac" \
  --query value[0].message \
  --output tsv
