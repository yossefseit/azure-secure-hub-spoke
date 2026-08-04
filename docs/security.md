# Security model

## Trust boundaries

| Boundary | Control |
|---|---|
| Internet to workloads | No public IP resources; default NSG deny remains in place |
| Hub to spokes | Explicit bidirectional peerings |
| Spoke to spoke | No direct peering and no transit service |
| Workload to PaaS | Private Endpoint and private DNS |
| Storage data plane | Public network disabled, shared-key authorization disabled |
| Administrative deployment | Exact subscription selection, preflight validation, `what-if`, explicit confirmation |
| Temporary validation | Private VM, SSH key only, Azure control-plane Run Command |

## NSG strategy

Each spoke has separate workload and private-endpoint NSGs. Approved TCP traffic is allowed at priority 100. Other traffic matching the `VirtualNetwork` service tag is denied at priority 4000, before Azure’s default `AllowVnetInBound` rule.

This is deliberate: after VNet peering, the `VirtualNetwork` tag can include remote VNet address spaces. Relying only on Azure’s default rules could therefore permit more lateral traffic than intended.

Each spoke route table also blackholes the other spoke prefix. This protects the intended no-transit baseline if a future change introduces an otherwise matching route. ASGs identify spoke workload NICs; the optional validation NIC joins the app ASG.

## Storage protections

The application storage account enforces:

- HTTPS only
- TLS 1.2 minimum
- no anonymous Blob access
- public network access disabled
- no shared-key authorization
- OAuth as the default authorization mode
- infrastructure encryption
- Blob versioning, change feed, and seven-day soft delete

The diagnostic storage account differs because trusted Azure monitoring services may need to write logs. It retains `AzureServices` bypass with a default-deny firewall posture. Review service compatibility before further restricting authentication.

## Administrative RBAC

The template creates no role assignments. Operator authorization remains an external prerequisite, which avoids granting access from a portfolio template but means deployment is not a zero-touch identity bootstrap.

Because the entry point is a subscription-scope deployment that creates resource groups, the deployment identity needs `Microsoft.Resources/deployments/*`, resource-group creation, and the actions for the declared Network, Storage, Compute, Operational Insights, and Insights resources at the relevant scopes. `Owner` is not required because the template creates no RBAC assignments. A time-bound `Contributor` assignment at subscription scope is operationally simple for a personal lab but broader than least privilege; a production pipeline should use a reviewed custom role and remove or expire the assignment after teardown.

Enabling VNet flow logs also requires write access to the existing Network Watcher resource group. The optional VM has a system-assigned identity but performs no Azure data-plane operation, so this lab intentionally assigns it no role.

## Secrets

No secret belongs in the repository. In particular, do not commit:

- tenant or subscription identifiers
- deployment credentials
- storage keys or SAS tokens
- SSH private keys
- `.env` files
- exported Azure profiles

The optional SSH public key belongs in a local `*.local.bicepparam` file, which `.gitignore` excludes.

## Known limitations

- The baseline has no centralized firewall or NVA, so it does not provide spoke-to-spoke inspection or transit.
- Log Analytics public ingestion and query endpoints remain enabled in the low-cost baseline. Private Link for Azure Monitor would add complexity and cost.
- VNet flow logs are disabled by default until the existing Network Watcher is resolved. Cleanup removes project flow logs from that pre-existing resource group before deleting their target networks/storage.
- No Azure Policy assignment is included; governance belongs in the separate governance project.
- The Bicep implementation is not proof of deployment. Only successful authorized validation and runtime evidence close that gap.
