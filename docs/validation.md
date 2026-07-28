# Validation record

This document separates implemented controls from tests that require an Azure subscription.

## Automated repository checks

| Check | Expected | Current status |
|---|---|---|
| Bicep lint | No errors | Pending first GitHub Actions run |
| Bicep compilation | ARM JSON generated | Pending first GitHub Actions run |
| ShellCheck | No script findings | Pending first GitHub Actions run |

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

