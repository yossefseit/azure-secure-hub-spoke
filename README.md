# Azure Secure Hub-Spoke

[![Validate infrastructure](https://github.com/yossefseit/azure-secure-hub-spoke/actions/workflows/validate.yml/badge.svg)](https://github.com/yossefseit/azure-secure-hub-spoke/actions/workflows/validate.yml)

A private-by-default Azure network foundation implemented with modular Bicep. The lab demonstrates network segmentation, Private Link, monitoring, guarded automation, and explicit cost and evidence boundaries.

## Status

| Area | Status | Evidence |
|---|---|---|
| Modular Bicep implementation | Implemented | `infra/main.bicep` and reusable modules |
| Offline lint, compilation, script, link, and secret checks | Automated | GitHub Actions workflow |
| Authenticated Azure validation | Pending | Requires an authorized subscription |
| Azure `what-if` review | Pending | Performed by `scripts/deploy.ps1` or `scripts/deploy.sh` before deployment |
| Live deployment | Pending | No cloud deployment is claimed yet |
| Private DNS and HTTPS test | Prepared | Optional ephemeral VM and validation script |
| Guarded teardown | Prepared | Offline failure-path tests; live teardown evidence remains pending |

## What this project demonstrates

- Hub-and-spoke topology with dedicated hub, application, and data VNets
- Bidirectional hub-to-spoke peering without direct spoke-to-spoke connectivity
- Workload and private-endpoint subnet separation
- NSGs that allow approved traffic before denying other lateral VNet traffic
- Application Security Groups for workload NIC identity and no-cost route tables that blackhole unintended cross-spoke prefixes
- No public IP resources and explicit private-subnet outbound behavior
- Private Blob Storage access through Private Link and Azure Private DNS
- Shared-key-disabled application storage with TLS 1.2, versioning, and soft delete
- Log Analytics with Blob audit diagnostics, an action group, a resource-group deletion alert, and hardened diagnostic storage
- Optional current-generation **VNet flow logs**, disabled until an existing Network Watcher is confirmed
- An optional, temporary private VM for DNS and endpoint reachability tests
- CI linting and Bicep compilation, deployment-time validation and `what-if`, scoped teardown, and cost guardrails

## Architecture

```mermaid
flowchart TB
  subgraph Azure["Azure subscription"]
    subgraph NetworkRG["Network resource group"]
      Hub["Hub VNet\n10.0.0.0/16"]
      App["App spoke\n10.10.0.0/16"]
      Data["Data spoke\n10.20.0.0/16"]
      DNS["Private DNS\nprivatelink.blob.core.windows.net"]
    end

    subgraph WorkloadRG["Workload resource group"]
      TestVM["Optional test VM\nNo public IP"]
      PE["Blob private endpoint"]
      Storage["Private Storage\nPublic access disabled"]
    end

    subgraph MonitorRG["Monitoring resource group"]
      LAW["Log Analytics"]
      Action["Action group"]
      Diag["Diagnostic storage"]
    end
  end

  Hub <--> App
  Hub <--> Data
  TestVM --> PE --> Storage
  DNS -.-> Hub
  DNS -.-> App
  PE -.-> DNS
  Hub -.-> Diag
  App -.-> Diag
  Data -.-> Diag
  LAW --> Action
```

The dashed VNet-to-diagnostic-storage paths represent optional VNet flow logs, which are disabled in the default parameters.

The peerings are intentionally non-transitive. The app and data spokes cannot route through the hub without a routing service such as Azure Firewall, an NVA, or Virtual WAN. Those services are excluded from the default lab because they materially increase cost.

See [architecture details](docs/architecture.md) and the [security model](docs/security.md).

![Implemented Azure secure hub-and-spoke architecture](diagrams/azure-secure-hub-spoke.svg)

## Repository structure

```text
.
├── .github/
│   ├── dependabot.yml
│   └── workflows/validate.yml
├── AGENTS.md
├── docs/
│   ├── architecture.md
│   ├── cleanup.md
│   ├── cost-estimate.md
│   ├── costs.md
│   ├── deployment-guide.md
│   ├── runbook.md
│   ├── security-decisions.md
│   ├── security.md
│   ├── testing.md
│   ├── troubleshooting.md
│   └── validation.md
├── diagrams/
│   ├── azure-secure-hub-spoke.drawio
│   └── azure-secure-hub-spoke.svg
├── infra/
│   ├── environments/lab.bicepparam
│   ├── modules/
│   └── main.bicep
├── scripts/
│   ├── deploy.sh
│   ├── deploy.ps1
│   ├── cleanup.ps1
│   ├── destroy.sh
│   ├── test-connectivity.sh
│   ├── validate-live.ps1
│   ├── validate.ps1
│   └── validate.sh
├── tests/
│   └── cleanup-failure-guards.sh
├── bicepconfig.json
└── README.md
```

## Prerequisites

- An Azure subscription that you own or are explicitly authorized to use
- Subscription-level permission to create resource groups and their resources
- Azure CLI with Bicep support
- Bash, Git, and an SSH public key only if the temporary VM is enabled

Do not deploy personal lab resources into an employer subscription without authorization.

## Validate locally

```bash
git clone https://github.com/yossefseit/azure-secure-hub-spoke.git
cd azure-secure-hub-spoke
chmod +x scripts/*.sh
./scripts/validate.sh
```

This lints and compiles the Bicep without creating Azure resources. PowerShell 7 users can run `./scripts/validate.ps1`. When `AZURE_SUBSCRIPTION_ID` is set and the already-active Azure CLI subscription matches, either path also runs Resource Manager preflight validation. The scripts never silently change subscriptions.

## Review and deploy

```bash
export AZURE_SUBSCRIPTION_ID="<authorized-subscription-id>"
./scripts/deploy.sh
```

The script:

1. Verifies the already-active Azure CLI subscription against the exact supplied ID.
2. Lints, compiles, and validates the Bicep.
3. displays an Azure Resource Manager `what-if` preview.
4. Requires an explicit `DEPLOY` confirmation.
5. Creates a named subscription-level deployment.

`DEPLOYMENT_LOCATION` controls the subscription deployment-record location; edit the Bicep `location` parameter to change resource location. No VM, flow log, Firewall, VPN Gateway, or Bastion resource is enabled by default.

## Validate private connectivity

Temporarily set `deployTestVm = true` and provide an SSH public key in a local, untracked `.bicepparam` file. Deploy, then run:

```bash
export AZURE_SUBSCRIPTION_ID="<authorized-subscription-id>"
./scripts/test-connectivity.sh
```

The script uses Azure VM Run Command—no public IP or inbound SSH rule—and fails unless the Blob hostname resolves to an RFC1918 address and HTTPS returns an expected authentication/client error. The app workload subnet permits platform default outbound access only while the optional VM is enabled so its agent can reach Azure control-plane endpoints. Remove the VM immediately after recording evidence.

## Clean up

```bash
export AZURE_SUBSCRIPTION_ID="<authorized-subscription-id>"
PREFIX="ashs" ENVIRONMENT="lab" ./scripts/destroy.sh
```

The cleanup scripts derive exactly three project resource-group names, verify canonical ownership tags and every contained resource, remove only name-and-tag-matched optional flow logs from the existing Network Watcher resource group, and require `DELETE ashs-lab`. They stop if any ownership or inventory query fails and do not delete arbitrary tagged resources or an entire subscription. See [cleanup details](docs/cleanup.md).

## Cost controls

The default template avoids the lab’s major cost drivers:

- no Azure Firewall
- no VPN Gateway or ExpressRoute
- no Bastion
- no NAT Gateway or public IP
- no always-on VM
- no Traffic Analytics
- seven-day flow-log retention when explicitly enabled

Storage transactions, Private Link, Log Analytics ingestion, and optional compute can still incur charges. Review the [USD 5 deployment limit and evidence requirements](docs/cost-estimate.md) before deployment.

## Evidence checklist

After an authorized deployment, add redacted evidence under `docs/evidence/`:

- successful GitHub Actions run
- Bicep `what-if` summary
- deployed resource-group overview
- VNet topology and peering status
- storage public-network setting and private endpoint approval
- private DNS resolution from the temporary VM
- expected HTTPS response from the private endpoint
- teardown confirmation and final cost review

Never publish subscription IDs, tenant IDs, access tokens, SSH keys, public IPs, or unredacted corporate information.

## Design references

- [Hub-spoke network topology](https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke)
- [Private Link and DNS integration at scale](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale)
- [Bicep best practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Bicep modules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/modules)
- [Azure Resource Manager what-if](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if)
- [Virtual Network flow logs](https://learn.microsoft.com/azure/network-watcher/vnet-flow-logs-overview)
- [Azure Storage private endpoints](https://learn.microsoft.com/azure/storage/common/storage-private-endpoints)
- [Default outbound access in Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)
- [Private Endpoint network policies](https://learn.microsoft.com/azure/private-link/disable-private-endpoint-network-policy)
- [Azure RBAC best practices](https://learn.microsoft.com/azure/role-based-access-control/best-practices)

## License

Code and original documentation are available under the [MIT License](LICENSE).
