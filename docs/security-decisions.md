# Security decisions

## Implemented controls

| Decision | Control | Trade-off |
|---|---|---|
| Private PaaS access | Blob public network access and shared keys disabled; Private Endpoint plus Private DNS | Private Endpoint has an hourly charge |
| Network segmentation | Separate hub/app/data VNets and subnets; bidirectional hub peerings only | Peering is non-transitive and is not a firewall |
| Lateral traffic | Explicit NSG allow rules followed by a VNet deny; route tables blackhole the other spoke CIDR | Production inspection still requires a Firewall/NVA/Virtual WAN |
| Workload grouping | Application Security Groups are created for spoke workloads; the optional test NIC joins the app ASG | Baseline has no steady-state workload NIC |
| Management | No public IP or inbound SSH rule; optional VM uses Azure Run Command | The temporary VM needs outbound platform access while enabled |
| Data protection | HTTPS/TLS 1.2, infrastructure encryption, Blob versioning/change feed/soft delete | CMK is excluded from this low-cost lab |
| Monitoring | Blob audit logs and transaction metrics go to Log Analytics; an Activity Log alert targets project RG deletion | Empty action group records events but sends no email until configured |
| Automation | Active subscription must already match; validate and `what-if` precede explicit confirmation | Human review remains a required control |

## Governance

Canonical `project`, `environment`, `managedBy`, and `repository` tags override optional user tags. Optional VNet flow logs receive the same tags even though they live in a pre-existing Network Watcher resource group. Cleanup refuses to delete a project resource group when canonical tags do not match or when a contained resource lacks the expected project, manager, or environment tag; flow logs must match both the expected deployment name and canonical tags.

Resource locks are **not implemented** because locks would intentionally block repeatable automated cleanup. A production environment should apply `CanNotDelete` locks through a separate lifecycle with an authorized lock-removal runbook.

Azure Policy and RBAC assignments are **planned for a separate governance project**. This lab does not create broad subscription permissions.

## Lab versus production

Azure Firewall or a hardened NVA, DNS Private Resolver, DDoS Network Protection, private Azure Monitor endpoints, Defender plans, and hybrid gateways are production recommendations—not baseline resources and not claimed as implemented. They require a new threat model, cost approval, and validation plan.

See the fuller [security model](security.md).
