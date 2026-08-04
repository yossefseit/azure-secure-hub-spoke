# Cleanup

Cleanup is destructive and requires exact ownership verification plus an explicit phrase.

PowerShell:

```powershell
./scripts/cleanup.ps1 -SubscriptionId '<authorized-subscription-id>' -Prefix ashs -Environment lab
```

Bash:

```bash
export AZURE_SUBSCRIPTION_ID='<authorized-subscription-id>'
PREFIX=ashs ENVIRONMENT=lab ./scripts/destroy.sh
```

Both paths:

1. verify the active subscription already matches;
2. derive exactly three resource-group names;
3. require `project=azure-secure-hub-spoke`, `managedBy=bicep`, and the expected environment tag;
4. stop if any contained resource lacks those canonical ownership tags or belongs to another environment;
5. stop if the Network Watcher group or flow-log inventory cannot be verified;
6. stop if a name-matched VNet flow log lacks the canonical ownership tags;
7. remove only VNet flow logs whose name and canonical ownership tags match this deployment;
8. require `DELETE ashs-lab` before deleting the three groups.

Afterward, confirm the groups and project flow logs are absent, then review Cost Management after usage data is processed. A passed cleanup claim requires captured sanitized output; current evidence is **pending**.

`tests/cleanup-failure-guards.sh` uses a mock Azure CLI to prove that both cleanup implementations abort when resource-group existence checks or flow-log inventory fail, when a contained resource belongs to another environment, and when a name-matched flow log lacks ownership tags. It also verifies that the PowerShell path stops when resource-group inspection or contained-resource inventory fails. These are offline negative tests, not teardown evidence from Azure.
