# Validation record

This document separates implemented controls from tests that require an Azure subscription.

## Automated repository checks

| Check | Expected | Current status |
|---|---|---|
| Bicep lint | No errors | Passed — GitHub Actions run 11, 2026-07-28 |
| Bicep compilation | ARM JSON generated | Passed — GitHub Actions run 11, 2026-07-28 |
| ShellCheck | No script findings | Passed — GitHub Actions run 11, 2026-07-28 |

The expanded feature branch additionally compiles the parameter file, parses PowerShell, checks Markdown links, and scans for secrets. Local Bicep 0.46.1 build/lint/parameter compilation, ShellCheck 0.11.0, and PowerShell 7.5 syntax checks passed on 2026-08-03. Pull-request CI evidence remains pending until the branch is published.

Evidence: [Validate infrastructure run 11](https://github.com/yossefseit/azure-secure-hub-spoke/actions/runs/30334716681).

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
