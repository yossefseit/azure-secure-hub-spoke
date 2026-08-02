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
4. stop if any contained resource lacks project ownership tags;
5. remove matching project VNet flow logs from `NetworkWatcherRG` when present;
6. require `DELETE ashs-lab` before deleting the three groups.

Afterward, confirm the groups and project flow logs are absent, then review Cost Management after usage data is processed. A passed cleanup claim requires captured sanitized output; current evidence is **pending**.
