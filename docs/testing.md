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
| Bicep lint | `az bicep lint --file infra/main.bicep` | Locally validated after final implementation; CI required on PR |
| Bicep build | `az bicep build --file infra/main.bicep` | Locally validated after final implementation; CI required on PR |
| Parameter compilation | `az bicep build-params --file infra/environments/lab.bicepparam` | Locally validated after final implementation; CI required on PR |
| Bash analysis | `shellcheck scripts/*.sh` | CI required on PR |
| PowerShell parse | workflow parser step | CI required on PR |
| Markdown links | Lychee workflow step | CI required on PR |
| Secret scan | Gitleaks workflow step | CI required on PR |

## Requires live Azure deployment

Run `scripts/validate-live.ps1` after deployment. It checks resource existence, address spaces, subnets, peerings, NSGs, route-table associations, Storage exposure, Private Endpoint approval, Private DNS records, diagnostic settings, Log Analytics linkage, and deployment outputs.

The private connectivity assertion additionally requires the temporary VM:

```bash
./scripts/test-connectivity.sh
```

The test fails unless the Blob FQDN resolves to an RFC1918 address and HTTPS returns `400`, `401`, or `403` rather than timing out.

## Evidence policy

Store only sanitized evidence in `docs/evidence/`. Redact subscription IDs, tenant IDs, email addresses, keys, tokens, and unrelated resources. Record timestamp, command, exit status, expected condition, and observed result. Current live evidence is **pending** until these checks actually run.
