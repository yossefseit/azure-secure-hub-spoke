#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_FILE="${REPOSITORY_ROOT}/infra/main.bicep"
PARAMETER_FILE="${1:-${REPOSITORY_ROOT}/infra/environments/lab.bicepparam}"
DEPLOYMENT_LOCATION="${DEPLOYMENT_LOCATION:-eastus2}"

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required: https://learn.microsoft.com/cli/azure/install-azure-cli" >&2
  exit 1
}

echo "Linting ${TEMPLATE_FILE}"
az bicep lint --file "${TEMPLATE_FILE}"

echo "Compiling ${TEMPLATE_FILE}"
az bicep build --file "${TEMPLATE_FILE}" --stdout >/dev/null

if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  echo "Running subscription-level preflight validation"
  ACTIVE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  if [[ "${ACTIVE_SUBSCRIPTION_ID}" != "${AZURE_SUBSCRIPTION_ID}" ]]; then
    echo "Active Azure subscription does not match AZURE_SUBSCRIPTION_ID; select it explicitly before continuing." >&2
    exit 1
  fi
  az deployment sub validate \
    --location "${DEPLOYMENT_LOCATION}" \
    --parameters "${PARAMETER_FILE}" \
    --only-show-errors
else
  echo "AZURE_SUBSCRIPTION_ID is unset; authenticated preflight validation was skipped."
fi
