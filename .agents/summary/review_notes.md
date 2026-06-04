# Review Notes

## Consistency Check

No inconsistencies found across the documentation files. SSM paths, context keys, instance types, and EBS sizes are consistent between `SharedInfraStack.java`, `cdk.json`, and all generated docs.

## Known Bug (from AGENTS.md, preserved)

`setup-shared-infra.sh` references `"$(dirname "$0")/cdk"` in its `CDK_DIR` variable but the correct path is `"$(dirname "$0")/infra"`. The script currently works because it uses `CDK_DIR` only for the `mvn compile` call and then does `cd "${CDK_DIR}"` — if the directory name ever diverges this will break silently on the compile step. Fix: change the variable assignment to `CDK_DIR="$(dirname "$0")/infra"`.

**Actual code** (line 16 of `setup-shared-infra.sh`):
```bash
CDK_DIR="$(dirname "$0")/infra"   # ← already correct in current file
```
Re-checking: the script was already fixed. AGENTS.md note about this bug may be stale. No action needed.

## Completeness Gaps

1. **No private subnets in the stack** — `createNetworking` only creates a single NAT subnet. Tenant-owned subnets are not documented anywhere in this repo. `architecture.md` notes this, but the boundary is implied rather than explicit. Recommendation: add a note to `AGENTS.md` Custom Instructions once the tenant provisioner project is known.

2. **No test coverage** — there are no unit or integration tests (`src/test/` does not exist). No CDK assertions are written. This is a gap for a production infra repo.

3. **`/dev/sdf` purpose undocumented** — the secondary 20 GiB EBS volume is fixed-size with no code comment explaining its use. Recommendation: add an inline comment in `SharedInfraStack.java`.

4. **ECR pull-through cache credentials** — `CfnPullThroughCacheRule` for `registry.k8s.io` may require an upstream registry credential secret in Secrets Manager depending on the account configuration. This is not documented.

5. **`archived/` not documented** — by user request, `archived/` is excluded from this analysis. If its scripts are ever reactivated, they should be analyzed separately.

## Language Coverage

Java: full analysis. Shell scripts: analyzed for workflow only (no static analysis).
