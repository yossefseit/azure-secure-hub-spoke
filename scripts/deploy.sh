#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PARAMETER_FILE="${1:-${REPOSITORY_ROOT}/infra/environments/lab.bicepparam}"
DEPLOYMENT_LOCATION="${DEPLOYMENT_LOCATION:-eastus2}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-azure-secure-hub-spoke}"

if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  echo "Set AZURE_SUBSCRIPTION_ID to an authorized subscription before deployment." >&2
  exit 1
fi

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required: https://learn.microsoft.com/cli/azure/install-azure-cli" >&2
  exit 1
}

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
CURRENT_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
CURRENT_SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"

if [[ "${CURRENT_SUBSCRIPTION_ID}" != "${AZURE_SUBSCRIPTION_ID}" ]]; then
  echo "Azure CLI selected an unexpected subscription. Deployment stopped." >&2
  exit 1
fi

echo "Subscription: ${CURRENT_SUBSCRIPTION_NAME} (${CURRENT_SUBSCRIPTION_ID})"
echo "Parameter file: ${PARAMETER_FILE}"

"${SCRIPT_DIR}/validate.sh" "${PARAMETER_FILE}"

echo "Previewing changes with Azure Resource Manager what-if"
az deployment sub what-if \
  --name "${DEPLOYMENT_NAME}" \
  --location "${DEPLOYMENT_LOCATION}" \
  --parameters "${PARAMETER_FILE}"

read -r -p "Type DEPLOY to apply this exact plan: " confirmation
if [[ "${confirmation}" != "DEPLOY" ]]; then
  echo "Deployment cancelled."
  exit 0
fi

az deployment sub create \
  --name "${DEPLOYMENT_NAME}" \
  --location "${DEPLOYMENT_LOCATION}" \
  --parameters "${PARAMETER_FILE}" \
  --only-show-errors \
  --output json

echo "Deployment completed. Record evidence, run validation, and remove temporary resources."

