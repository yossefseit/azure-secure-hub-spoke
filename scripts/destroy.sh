#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-ashs}"
ENVIRONMENT="${ENVIRONMENT:-lab}"

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

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
CURRENT_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
CURRENT_SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
BASE_NAME="${PREFIX}-${ENVIRONMENT}"

RESOURCE_GROUPS=(
  "rg-${BASE_NAME}-network"
  "rg-${BASE_NAME}-workload"
  "rg-${BASE_NAME}-monitoring"
)

echo "Subscription: ${CURRENT_SUBSCRIPTION_NAME} (${CURRENT_SUBSCRIPTION_ID})"
printf 'Resource groups scheduled for deletion:\n'
printf '  %s\n' "${RESOURCE_GROUPS[@]}"

read -r -p "Type DELETE ${BASE_NAME} to continue: " confirmation
if [[ "${confirmation}" != "DELETE ${BASE_NAME}" ]]; then
  echo "Deletion cancelled."
  exit 0
fi

for resource_group in "${RESOURCE_GROUPS[@]}"; do
  if az group exists --name "${resource_group}" | grep -qx true; then
    az group delete --name "${resource_group}" --yes
  else
    echo "Skipping missing resource group: ${resource_group}"
  fi
done

echo "Project resource groups deleted."

