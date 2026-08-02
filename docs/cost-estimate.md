# Cost estimate and limit

## Autonomous limit

The approved incremental limit is **USD 5 total**, not USD 5 per month. No live deployment may proceed without a current Azure Pricing Calculator review for the selected region and a short deployment/teardown window.

## Billable baseline

The primary cost-generating resources are the Private Endpoint, Blob and diagnostic storage, Log Analytics ingestion/retention, and peering data transfer. Empty VNets, subnets, NSGs, ASGs, route tables, and Private DNS configuration are not the main cost drivers.

The optional `Standard_B1s` VM and VNet flow logs are disabled by default. If enabled, keep the VM only long enough to validate DNS/HTTPS and remove it with the project resource groups. Raw flow logs can continue generating storage transactions until their flow-log resources are removed.

## Excluded premium services

Azure Firewall, VPN/ExpressRoute gateways, Application Gateway, Bastion, NAT Gateway, DDoS Network Protection, Traffic Analytics, paid Defender plans, and always-on compute are not deployed.

## Required evidence

Before deployment, save a sanitized calculator summary showing that the planned duration remains below USD 5. After cleanup, record start/end timestamps, resources retained, and Cost Management results after billing data settles. Until then the exact cost is **evidence pending**.

The older [cost controls](costs.md) remain a concise operational checklist.
