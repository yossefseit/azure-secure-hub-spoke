#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-ashs}"
ENVIRONMENT="${ENVIRONMENT:-lab}"

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required." >&2
  exit 1
}

if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  echo "Set AZURE_SUBSCRIPTION_ID to the authorized deployment subscription." >&2
  exit 1
fi

if [[ ! "${PREFIX}" =~ ^[a-z0-9]{3,8}$ ]]; then
  echo "PREFIX must be 3-8 lowercase letters or digits." >&2
  exit 1
fi

if [[ ! "${ENVIRONMENT}" =~ ^(lab|dev|test)$ ]]; then
  echo "ENVIRONMENT must be lab, dev, or test." >&2
  exit 1
fi

CURRENT_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
CURRENT_SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
if [[ "${CURRENT_SUBSCRIPTION_ID}" != "${AZURE_SUBSCRIPTION_ID}" ]]; then
  echo "Active Azure subscription does not match AZURE_SUBSCRIPTION_ID. Select it explicitly before cleanup." >&2
  exit 1
fi
BASE_NAME="${PREFIX}-${ENVIRONMENT}"

RESOURCE_GROUPS=(
  "rg-${BASE_NAME}-network"
  "rg-${BASE_NAME}-workload"
  "rg-${BASE_NAME}-monitoring"
)

echo "Subscription: ${CURRENT_SUBSCRIPTION_NAME} (${CURRENT_SUBSCRIPTION_ID})"
printf 'Resource groups scheduled for deletion:\n'
printf '  %s\n' "${RESOURCE_GROUPS[@]}"

for resource_group in "${RESOURCE_GROUPS[@]}"; do
  if ! az group exists --name "${resource_group}" | grep -qx true; then
    echo "Skipping ownership check for missing resource group: ${resource_group}"
    continue
  fi

  project_tag="$(az group show --name "${resource_group}" --query "tags.project" --output tsv)"
  managed_by_tag="$(az group show --name "${resource_group}" --query "tags.managedBy" --output tsv)"
  environment_tag="$(az group show --name "${resource_group}" --query "tags.environment" --output tsv)"
  if [[ "${project_tag}" != "azure-secure-hub-spoke" || "${managed_by_tag}" != "bicep" || "${environment_tag}" != "${ENVIRONMENT}" ]]; then
    echo "Ownership verification failed for ${resource_group}; cleanup stopped." >&2
    exit 1
  fi

  unexpected_resources="$(az resource list --resource-group "${resource_group}" --query "[?tags.project!='azure-secure-hub-spoke' || tags.managedBy!='bicep'].id" --output tsv)"
  if [[ -n "${unexpected_resources}" ]]; then
    echo "Unowned resources exist in ${resource_group}; cleanup stopped:" >&2
    echo "${unexpected_resources}" >&2
    exit 1
  fi
done

read -r -p "Type DELETE ${BASE_NAME} to continue: " confirmation
if [[ "${confirmation}" != "DELETE ${BASE_NAME}" ]]; then
  echo "Deletion cancelled."
  exit 0
fi

NETWORK_WATCHER_RESOURCE_GROUP="${NETWORK_WATCHER_RESOURCE_GROUP:-NetworkWatcherRG}"
if az group exists --name "${NETWORK_WATCHER_RESOURCE_GROUP}" | grep -qx true; then
  mapfile -t project_flow_log_ids < <(
    az resource list \
      --resource-group "${NETWORK_WATCHER_RESOURCE_GROUP}" \
      --resource-type 'Microsoft.Network/networkWatchers/flowLogs' \
      --query "[?contains(name, 'flow-${BASE_NAME}-')].id" \
      --output tsv
  )
  for flow_log_id in "${project_flow_log_ids[@]}"; do
    az resource delete --ids "${flow_log_id}"
  done
fi

for resource_group in "${RESOURCE_GROUPS[@]}"; do
  if az group exists --name "${resource_group}" | grep -qx true; then
    az group delete --name "${resource_group}" --yes
  else
    echo "Skipping missing resource group: ${resource_group}"
  fi
done

echo "Project resource groups deleted."
