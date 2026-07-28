# Cost controls

## Baseline

VNets, subnets, NSGs, route-free peering configuration, and Private DNS zone configuration are not the primary cost drivers. The resources most likely to produce charges are:

- VNet peering data transfer
- Private Endpoint hours and processed data
- Storage capacity, transactions, and flow-log writes
- Log Analytics ingestion and retention
- the optional VM while allocated

Pricing varies by region and agreement. Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) before deployment and review the actual subscription’s Cost Management data afterward.

## Excluded by default

The template does not deploy:

- Azure Firewall
- VPN Gateway
- ExpressRoute
- Azure Bastion
- NAT Gateway
- DDoS Network Protection
- Traffic Analytics
- always-on compute

These services can turn a small learning lab into a material monthly bill.

## Deployment discipline

1. Set a subscription budget and notification before deploying.
2. Run `what-if` and confirm every billable resource.
3. Keep `deployTestVm` and `enableVnetFlowLogs` false until their tests are scheduled.
4. Deploy the test VM only for the validation window.
5. Capture redacted evidence.
6. Delete all three project resource groups.
7. Recheck Cost Analysis after usage data arrives.

## Cost evidence

Record:

- calculator estimate before deployment
- deployment start and teardown timestamps
- resources that remained active
- final cost after billing data settles
- any difference between estimate and actual cost

Do not publish billing-account identifiers or corporate pricing.

