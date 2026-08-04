# Validation record

This document separates implemented controls from tests that require an Azure subscription.

## Automated repository checks

| Check | Expected | Current status |
|---|---|---|
| Bicep lint and compilation | No diagnostics; ARM JSON generated | Automated in GitHub Actions |
| Parameter compilation | ARM parameters JSON generated | Automated in GitHub Actions |
| ShellCheck | No script findings | Automated in GitHub Actions |
| PowerShell parse and analysis | No parser or PSScriptAnalyzer warning/error findings | Automated in GitHub Actions |
| Cleanup failure guards | Both paths fail closed on inventory errors and unowned name matches | Automated with a mock Azure CLI; no Azure resources touched |
| Markdown links | Reachable local and external targets | Automated in GitHub Actions |
| Secret scan | No detected credentials in repository history | Automated in GitHub Actions |

Historical baseline evidence: [successful `main` workflow after pull request 2](https://github.com/yossefseit/azure-secure-hub-spoke/actions/runs/30770400699). For later changes, the workflow badge and run associated with the exact commit are authoritative.

## Azure preflight

| Check | Evidence | Status |
|---|---|---|
| Resource Manager validation | Redacted CLI result | Not run |
| `what-if` review | Redacted change summary | Not run |
| Policy compatibility | Validation and deployment result | Not run |

## Runtime

| Check | Pass condition | Status |
|---|---|---|
| Hub/app peering | Both directions `Connected` | Not run |
| Hub/data peering | Both directions `Connected` | Not run |
| Public IP inventory | Zero project public IPs | Not run |
| Storage exposure | Public network disabled | Not run |
| Private endpoint | Connection approved | Not run |
| Private DNS | Blob FQDN resolves to RFC1918 address from app VNet | Not run |
| HTTPS reachability | Endpoint returns an authentication/client error, not a timeout | Not run |
| Spoke isolation | No unintended app-to-data path | Not run |
| Teardown | Three project resource groups absent | Not run |

## Evidence policy

- Use dates and exact commands.
- Redact tenant IDs, subscription IDs, email addresses, keys, and corporate identifiers.
- State failed or skipped tests plainly.
- Do not backfill expected results as if they were observed.
