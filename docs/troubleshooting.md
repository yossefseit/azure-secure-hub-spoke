# Troubleshooting

## Subscription mismatch

The scripts never change subscriptions silently. If the active ID differs from the supplied ID, review the intended tenant and run `az account set --subscription ...` yourself.

## Resource Manager validation fails

Read the complete error and check provider registration, Azure Policy, region availability, quota, API support, and naming rules. Do not proceed to `what-if` or deployment until validation passes.

## Private endpoint name resolves publicly

Confirm the `privatelink.blob.core.windows.net` zone exists, the app VNet link is complete, and the private endpoint zone group created an A record. Run the query from inside the app VNet; a workstation outside that DNS context is not a valid test.

## Run Command is unavailable

The optional VM requires outbound access to Azure platform endpoints. The app workload subnet enables platform default outbound access only while `deployTestVm=true`. If organizational policy blocks implicit outbound access, use an approved NAT or Azure Firewall design, document its cost, and do not claim the test passed.

## Spoke-to-spoke traffic fails

That is expected. VNet peering is non-transitive and each spoke route table blackholes the other spoke CIDR. A routed production scenario requires a transit appliance and revised UDR/NSG tests.

## Flow-log deployment fails

VNet flow logs are optional and require an existing regional Network Watcher. Verify its resource group/name and provider registration. Keep flow logs disabled when this dependency or its storage cost has not been approved.

## Cleanup stops on ownership verification

Do not bypass the guard. Inspect the resource-group tags and inventory. Manually resolve unrelated resources or naming collisions before rerunning cleanup.
