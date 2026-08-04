# Testing and evidence

## Status vocabulary

- **Implemented** — present in source.
- **Locally validated** — checked without creating Azure resources.
- **Requires live Azure deployment** — cannot be proven offline.
- **Live validated** — passed against deployed resources with sanitized evidence.
- **Evidence pending** — expected artifact has not been captured.
- **Planned** — intentionally outside the current implementation.
- **Blocked** — an external prerequisite prevents the check.

## Local and CI checks

| Check | Command | Status |
|---|---|---|
| Bicep lint | `az bicep lint --file infra/main.bicep` | Automated in `validate.yml`; confirm the badge for the current commit |
| Bicep build | `az bicep build --file infra/main.bicep` | Automated in `validate.yml`; confirm the badge for the current commit |
| Parameter compilation | `az bicep build-params --file infra/environments/lab.bicepparam` | Automated in `validate.yml`; confirm the badge for the current commit |
| Bash analysis | `shellcheck scripts/*.sh tests/*.sh` | Automated in `validate.yml` |
| PowerShell parse and analysis | workflow parser and PSScriptAnalyzer steps | Automated in `validate.yml` |
| Cleanup failure guards | `tests/cleanup-failure-guards.sh` | Mocked negative tests; no Azure resources are touched |
| Markdown links | Lychee workflow step | Automated in `validate.yml` |
| Secret scan | Gitleaks workflow step | Automated in `validate.yml` |

## Requires live Azure deployment

Run `scripts/validate-live.ps1` after deployment. It derives resource names, environment, VNet ranges, subnet ranges, and the private DNS zone from the recorded deployment instead of local defaults. It then checks resource existence, address spaces, subnets, peerings, NSGs, route-table associations, Storage exposure, Private Endpoint approval, Private DNS records, diagnostic settings, Log Analytics linkage, and deployment outputs.

The private connectivity assertion additionally requires the temporary VM:

```bash
./scripts/test-connectivity.sh
```

The test fails unless the Blob FQDN resolves to an RFC1918 address and HTTPS returns `400`, `401`, or `403` rather than timing out.

## Evidence policy

Store only sanitized evidence in `docs/evidence/`. Redact subscription IDs, tenant IDs, email addresses, keys, tokens, and unrelated resources. Record timestamp, command, exit status, expected condition, and observed result. Current live evidence is **pending** until these checks actually run.
