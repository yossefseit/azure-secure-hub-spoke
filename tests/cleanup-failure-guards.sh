#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TEST_TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -r -- "${TEST_TEMP_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

BASH_MOCK_DIR="${TEST_TEMP_DIR}/bash-mock"
mkdir -p "${BASH_MOCK_DIR}"
cat >"${BASH_MOCK_DIR}/az" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  'account show')
    if [[ " $* " == *' --query id '* ]]; then
      echo 'sub-test'
    elif [[ " $* " == *' --query name '* ]]; then
      echo 'Test Subscription'
    else
      exit 90
    fi
    ;;
  'group exists')
    if [[ "${MOCK_FAILURE:-}" == 'group-exists' ]]; then
      echo 'simulated resource-group existence failure' >&2
      exit 41
    fi
    if [[ "${MOCK_FAILURE:-}" == 'wrong-environment-resource' && " $* " == *' --name rg-ashs-lab-network '* ]]; then
      echo 'true'
      exit 0
    fi
    if [[ " $* " == *' --name NetworkWatcherRG '* ]]; then
      echo 'true'
    else
      echo 'false'
    fi
    ;;
  'group show')
    if [[ " $* " == *' --query tags.project '* ]]; then
      echo 'azure-secure-hub-spoke'
    elif [[ " $* " == *' --query tags.managedBy '* ]]; then
      echo 'bicep'
    elif [[ " $* " == *' --query tags.environment '* ]]; then
      echo 'lab'
    else
      exit 92
    fi
    ;;
  'resource list')
    if [[ "${MOCK_FAILURE:-}" == 'wrong-environment-resource' && " $* " != *' --resource-type '* ]]; then
      if [[ "$*" == *"tags.environment!='lab'"* ]]; then
        echo '/subscriptions/sub-test/resourceGroups/rg-ashs-lab-network/providers/Microsoft.Network/virtualNetworks/vnet-wrong-environment'
      fi
      exit 0
    fi
    if [[ "${MOCK_FAILURE:-}" == 'flow-log-inventory' ]]; then
      echo 'simulated flow-log inventory failure' >&2
      exit 42
    fi
    if [[ "${MOCK_FAILURE:-}" == 'unowned-flow-log' && "$*" == *'!='* ]]; then
      echo '/subscriptions/sub-test/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_eastus2/flowLogs/flow-ashs-lab-0'
    fi
    ;;
  *)
    echo "unexpected mock Azure CLI call: $*" >&2
    exit 91
    ;;
esac
MOCK
chmod +x "${BASH_MOCK_DIR}/az"

set +e
bash_group_output="$({
  env PATH="${BASH_MOCK_DIR}:${PATH}" AZURE_SUBSCRIPTION_ID='sub-test' MOCK_FAILURE='group-exists' \
    "${REPOSITORY_ROOT}/scripts/destroy.sh" </dev/null
} 2>&1)"
bash_group_status=$?
set -e

if [[ ${bash_group_status} -eq 0 ]]; then
  fail 'Bash cleanup continued after the resource-group existence check failed.'
fi
if ! grep -Fq 'Could not verify whether rg-ashs-lab-network exists; cleanup stopped.' <<<"${bash_group_output}"; then
  fail "Bash cleanup did not report the resource-group guard. Output: ${bash_group_output}"
fi
echo 'PASS: Bash cleanup stops when resource-group existence checks fail.'

set +e
bash_environment_output="$({
  env PATH="${BASH_MOCK_DIR}:${PATH}" AZURE_SUBSCRIPTION_ID='sub-test' MOCK_FAILURE='wrong-environment-resource' \
    "${REPOSITORY_ROOT}/scripts/destroy.sh" </dev/null
} 2>&1)"
bash_environment_status=$?
set -e

if [[ ${bash_environment_status} -eq 0 ]]; then
  fail 'Bash cleanup continued after finding a resource tagged for another environment.'
fi
if ! grep -Fq 'Unowned resources exist in rg-ashs-lab-network; cleanup stopped:' <<<"${bash_environment_output}"; then
  fail "Bash cleanup did not report the environment ownership guard. Output: ${bash_environment_output}"
fi
echo 'PASS: Bash cleanup stops on contained resources tagged for another environment.'

set +e
bash_output="$({
  printf 'DELETE ashs-lab\n' | \
    env PATH="${BASH_MOCK_DIR}:${PATH}" AZURE_SUBSCRIPTION_ID='sub-test' MOCK_FAILURE='flow-log-inventory' \
    "${REPOSITORY_ROOT}/scripts/destroy.sh"
} 2>&1)"
bash_status=$?
set -e

if [[ ${bash_status} -eq 0 ]]; then
  fail 'Bash cleanup continued after the flow-log inventory command failed.'
fi
if ! grep -Fq 'Could not inventory project flow logs; cleanup stopped.' <<<"${bash_output}"; then
  fail "Bash cleanup did not report the guarded failure. Output: ${bash_output}"
fi
echo 'PASS: Bash cleanup stops when flow-log inventory fails.'

set +e
bash_unowned_output="$({
  printf 'DELETE ashs-lab\n' | \
    env PATH="${BASH_MOCK_DIR}:${PATH}" AZURE_SUBSCRIPTION_ID='sub-test' MOCK_FAILURE='unowned-flow-log' \
    "${REPOSITORY_ROOT}/scripts/destroy.sh"
} 2>&1)"
bash_unowned_status=$?
set -e

if [[ ${bash_unowned_status} -eq 0 ]]; then
  fail 'Bash cleanup continued after finding a name-matched unowned flow log.'
fi
if ! grep -Fq 'Name-matched flow logs lack the expected ownership tags; cleanup stopped:' <<<"${bash_unowned_output}"; then
  fail "Bash cleanup did not report the unowned flow log. Output: ${bash_unowned_output}"
fi
echo 'PASS: Bash cleanup stops on name-matched flow logs without ownership tags.'

if command -v pwsh >/dev/null 2>&1; then
  POWERSHELL_MOCK_DIR="${TEST_TEMP_DIR}/powershell-mock"
  mkdir -p "${POWERSHELL_MOCK_DIR}"
  cat >"${POWERSHELL_MOCK_DIR}/az" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  'account show')
    printf '%s\n' '{"id":"sub-test","name":"Test Subscription","tenantId":"tenant-test"}'
    ;;
  'group exists')
    if [[ "${MOCK_FAILURE:-}" == 'group-exists' ]]; then
      echo 'simulated resource-group existence failure' >&2
      exit 41
    fi
    if [[ ("${MOCK_FAILURE:-}" == 'group-inspection' || "${MOCK_FAILURE:-}" == 'resource-inventory' || "${MOCK_FAILURE:-}" == 'wrong-environment-resource') && " $* " == *' --name rg-ashs-lab-network '* ]]; then
      echo 'true'
      exit 0
    fi
    if [[ " $* " == *' --name NetworkWatcherRG '* ]]; then
      echo 'true'
    else
      echo 'false'
    fi
    ;;
  'group show')
    if [[ "${MOCK_FAILURE:-}" == 'group-inspection' ]]; then
      echo 'simulated resource-group inspection failure' >&2
      exit 44
    fi
    printf '%s\n' '{"tags":{"project":"azure-secure-hub-spoke","managedBy":"bicep","environment":"lab"}}'
    ;;
  'resource list')
    if [[ "${MOCK_FAILURE:-}" == 'resource-inventory' && " $* " != *' --resource-type '* ]]; then
      echo 'simulated resource inventory failure' >&2
      exit 43
    fi
    if [[ "${MOCK_FAILURE:-}" == 'wrong-environment-resource' && " $* " != *' --resource-type '* ]]; then
      if [[ "$*" == *"tags.environment!='lab'"* ]]; then
        echo '/subscriptions/sub-test/resourceGroups/rg-ashs-lab-network/providers/Microsoft.Network/virtualNetworks/vnet-wrong-environment'
      fi
      exit 0
    fi
    if [[ "${MOCK_FAILURE:-}" == 'flow-log-inventory' ]]; then
      echo 'simulated flow-log inventory failure' >&2
      exit 42
    fi
    if [[ "${MOCK_FAILURE:-}" == 'unowned-flow-log' && "$*" == *'!='* ]]; then
      echo '/subscriptions/sub-test/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_eastus2/flowLogs/flow-ashs-lab-0'
    fi
    ;;
  *)
    echo "unexpected mock Azure CLI call: $*" >&2
    exit 91
    ;;
esac
MOCK
  chmod +x "${POWERSHELL_MOCK_DIR}/az"

  set +e
  powershell_group_output="$({
    env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='group-exists' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test' </dev/null
  } 2>&1)"
  powershell_group_status=$?
  set -e

  if [[ ${powershell_group_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after the resource-group existence check failed.'
  fi
  if ! grep -Fq 'Could not verify whether rg-ashs-lab-network exists.' <<<"${powershell_group_output}"; then
    fail "PowerShell cleanup did not report the resource-group guard. Output: ${powershell_group_output}"
  fi
  echo 'PASS: PowerShell cleanup stops when resource-group existence checks fail.'

  set +e
  powershell_inspection_output="$({
    env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='group-inspection' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test' </dev/null
  } 2>&1)"
  powershell_inspection_status=$?
  set -e

  if [[ ${powershell_inspection_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after resource-group inspection failed.'
  fi
  if ! grep -Fq 'Could not inspect rg-ashs-lab-network; cleanup stopped.' <<<"${powershell_inspection_output}"; then
    fail "PowerShell cleanup did not report the resource-group inspection guard. Output: ${powershell_inspection_output}"
  fi
  echo 'PASS: PowerShell cleanup stops when resource-group inspection fails.'

  set +e
  powershell_inventory_output="$({
    env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='resource-inventory' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test' </dev/null
  } 2>&1)"
  powershell_inventory_status=$?
  set -e

  if [[ ${powershell_inventory_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after resource inventory failed during ownership verification.'
  fi
  if ! grep -Fq 'Could not inventory resources in rg-ashs-lab-network; cleanup stopped.' <<<"${powershell_inventory_output}"; then
    fail "PowerShell cleanup did not report the resource inventory guard. Output: ${powershell_inventory_output}"
  fi
  echo 'PASS: PowerShell cleanup stops when resource inventory fails during ownership verification.'

  set +e
  powershell_environment_output="$({
    env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='wrong-environment-resource' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test' </dev/null
  } 2>&1)"
  powershell_environment_status=$?
  set -e

  if [[ ${powershell_environment_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after finding a resource tagged for another environment.'
  fi
  if ! grep -Fq 'Unowned resources exist in rg-ashs-lab-network; cleanup stopped.' <<<"${powershell_environment_output}"; then
    fail "PowerShell cleanup did not report the environment ownership guard. Output: ${powershell_environment_output}"
  fi
  echo 'PASS: PowerShell cleanup stops on contained resources tagged for another environment.'

  set +e
  powershell_output="$({
    printf 'DELETE ashs-lab\n' | \
      env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='flow-log-inventory' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test'
  } 2>&1)"
  powershell_status=$?
  set -e

  if [[ ${powershell_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after the flow-log inventory command failed.'
  fi
  if ! grep -Fq 'Could not inventory project flow logs; cleanup stopped.' <<<"${powershell_output}"; then
    fail "PowerShell cleanup did not report the guarded failure. Output: ${powershell_output}"
  fi
  echo 'PASS: PowerShell cleanup stops when flow-log inventory fails.'

  set +e
  powershell_unowned_output="$({
    printf 'DELETE ashs-lab\n' | \
      env PATH="${POWERSHELL_MOCK_DIR}:${PATH}" MOCK_FAILURE='unowned-flow-log' \
      pwsh -NoLogo -NoProfile -File "${REPOSITORY_ROOT}/scripts/cleanup.ps1" -SubscriptionId 'sub-test'
  } 2>&1)"
  powershell_unowned_status=$?
  set -e

  if [[ ${powershell_unowned_status} -eq 0 ]]; then
    fail 'PowerShell cleanup continued after finding a name-matched unowned flow log.'
  fi
  if ! grep -Fq 'Name-matched flow logs lack the expected ownership tags; cleanup stopped.' <<<"${powershell_unowned_output}"; then
    fail "PowerShell cleanup did not report the unowned flow log. Output: ${powershell_unowned_output}"
  fi
  echo 'PASS: PowerShell cleanup stops on name-matched flow logs without ownership tags.'
else
  echo 'SKIP: PowerShell cleanup guard test requires pwsh; CI runs it on GitHub-hosted runners.'
fi
