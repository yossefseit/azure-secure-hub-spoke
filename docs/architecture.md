# Architecture

## Goal

Create a small but defensible Azure network foundation that demonstrates the patterns behind enterprise hub-spoke environments without requiring expensive managed routing services.

## Address plan

| Network | Address space | Subnets |
|---|---|---|
| Hub | `10.0.0.0/16` | Management `10.0.1.0/24`, shared services `10.0.2.0/24` |
| App spoke | `10.10.0.0/16` | Workload `10.10.1.0/24`, private endpoints `10.10.2.0/24` |
| Data spoke | `10.20.0.0/16` | Workload `10.20.1.0/24`, private endpoints `10.20.2.0/24` |

These are the default lab ranges. Each VNet and subnet prefix is an independent deployment parameter, so a customized address plan must keep every subnet inside its parent VNet and all three VNet ranges non-overlapping. Azure Resource Manager validation is required before deployment.

Each spoke has a route table attached to both subnets. The only explicit route blackholes the other spoke CIDR. This is a no-cost defense-in-depth guardrail against accidental cross-spoke reachability if peerings or system routes change; it is not a substitute for inspected transit. Application Security Groups provide workload identity for future NIC-based rules, and the optional app validation VM joins the app workload ASG.

## Connectivity

The template creates four peerings:

- hub to app
- app to hub
- hub to data
- data to hub

There is no app-to-data peering. Azure VNet peering is non-transitive, so the hub does not automatically route traffic between spokes. A production design requiring centralized inspection would add Azure Firewall, an NVA, or Virtual WAN and then apply UDRs. This lab does not imply that peering alone provides transit.

## Private service access

Blob Storage has public network access disabled. Its private endpoint is placed in the app spoke’s dedicated private-endpoint subnet, allowing an application workload in that VNet to reach the service without crossing the public internet.

The `privatelink.blob.core.windows.net` private zone lives in the network resource group and links to the hub and app VNet. The private endpoint zone group manages the Blob A record. The data spoke is not linked because it has no route to this private endpoint in the baseline design.

## Name resolution

The current lab uses Azure-provided DNS plus linked Azure Private DNS zones. The shared-services subnet and NSG reserve a future location for Azure DNS Private Resolver or a DNS-forwarding appliance, but no resolver is deployed or claimed.

## Monitoring

The baseline creates:

- a Log Analytics workspace
- an Azure Monitor action group
- a diagnostic storage account
- Blob audit-log and transaction-metric diagnostic settings targeting Log Analytics
- an Activity Log alert for deletion attempts against the three project resource groups

VNet flow logs are optional. They require an existing regional Network Watcher, incur storage transactions, and should be enabled only after confirming the watcher name and resource group.

## Validation workload

The optional `Standard_B1s` Ubuntu VM:

- has no public IP
- uses SSH-key-only authentication
- is reached through Azure VM Run Command
- exists only to validate private DNS and HTTPS reachability
- should be removed immediately after evidence is captured
- temporarily enables platform default outbound access on its app workload subnet so the VM agent can reach Azure control-plane endpoints

It is not a management jump host and is not part of the steady-state topology.

The maintainable diagram source is [`diagrams/azure-secure-hub-spoke.drawio`](../diagrams/azure-secure-hub-spoke.drawio); the exported web version is [`diagrams/azure-secure-hub-spoke.svg`](../diagrams/azure-secure-hub-spoke.svg).

## Future enterprise extensions

The following are valid next steps but are intentionally outside the default deployment:

- Azure Firewall or an NVA with forced routing
- Azure DNS Private Resolver
- site-to-site VPN or ExpressRoute
- Azure Bastion
- DDoS Network Protection
- multi-region spokes and Azure Front Door
- Azure Policy assignments at management-group scope

Each extension must include a cost estimate, threat-model change, validation plan, and teardown procedure before deployment.
