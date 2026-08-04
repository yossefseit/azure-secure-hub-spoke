# Repository guidance

These instructions apply to the entire repository.

## Safety and evidence

- Treat this as a personal Azure lab, not a production deployment.
- Do not run Resource Manager validation, `what-if`, deployment, VM Run Command, or cleanup without an explicitly authorized subscription and reviewed cost window.
- Never change the active Azure subscription in automation. Require the caller-supplied subscription ID to match the existing Azure CLI context.
- Keep `deployTestVm` and `enableVnetFlowLogs` disabled by default.
- Never commit subscription or tenant IDs, credentials, email addresses, SSH keys, exported Azure profiles, billing data, or unsanitized command output.
- Distinguish authored, locally or CI validated, authenticated ARM validated, `what-if` reviewed, deployed, runtime tested, and teardown tested. Do not promote a status without evidence.

## Validation

Run the strongest available offline checks before committing:

```bash
az bicep lint --file infra/main.bicep
az bicep build --file infra/main.bicep --stdout >/dev/null
az bicep build-params --file infra/environments/lab.bicepparam --outfile /tmp/azure-secure-hub-spoke.parameters.json
shellcheck scripts/*.sh tests/*.sh
tests/cleanup-failure-guards.sh
```

Also parse and analyze all PowerShell scripts with PowerShell 7 and PSScriptAnalyzer, validate the Draw.io/SVG XML, check Markdown links, and run a full-history secret scan when those tools are available. Generated ARM JSON and validation evidence belong in `/tmp`, not the repository.

## Conventions

- Keep the implementation dependency-light and modular under `infra/modules/`.
- Preserve Bash and PowerShell safety parity for validation, deployment, and cleanup.
- Canonical project tags must override optional caller tags and must be present on resources used by guarded cleanup.
- Cleanup must fail closed on authentication, ownership, inventory, or deletion errors and require the exact confirmation phrase.
- Update architecture, security, cost, testing, troubleshooting, and cleanup documentation whenever behavior changes.

## Definition of done

A change is complete only when static checks pass, the diff contains no secrets or unsupported claims, docs match the Bicep and scripts, cost-impacting options remain opt-in, cleanup behavior remains guarded, and the GitHub Actions run for the exact commit succeeds. Live Azure and teardown statuses stay pending until sanitized evidence exists.
