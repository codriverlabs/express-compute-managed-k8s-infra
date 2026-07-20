# Review Notes

## Consistency Check

| Item | Status | Notes |
|------|--------|-------|
| Instance type defaults match `cdk.json` | ✅ | `c6g.xlarge` (arm64), `m7i.large` (x86_64) |
| SSM paths consistent across docs | ✅ | All docs use `/express-compute/infra/...` |
| ECR cache prefixes match source | ✅ | `public-ecr/`, `registry-k8s-io/`, `quay-io/` |
| Script args match source | ✅ | `[region] [projectName]`, defaults verified |
| Release workflow matches source | ✅ | Bundles README + scripts + infra/ |
| NAT gateway conditionality documented | ✅ | Architecture + components both cover it |

### Previously Fixed Inconsistency

- README.md previously listed `instanceTypeArm64` default as `m7g.large` — corrected to `c6g.xlarge` to match `cdk.json` (fixed in commit `d308aeb`).

## Completeness Check

| Area | Coverage | Gap |
|------|----------|-----|
| Stack resources | ✅ Complete | — |
| Configuration options | ✅ Complete | — |
| Deploy/destroy workflow | ✅ Complete | — |
| Release workflow | ✅ Complete | — |
| Consumer integration | ✅ Documented | No code in this repo to verify consumer behavior |
| Testing | ⚠️ Gap | No test suite exists (`src/test/` absent) |
| Multi-account deployment | ⚠️ Gap | ECR pull-through cache for `registry.k8s.io` may need Secrets Manager credential — not documented in code |
| Subnet strategy | ⚠️ Gap | Only one subnet (`10.0.0.0/24`) is created; tenant provisioner presumably creates additional subnets — not documented here |
| Security group setup | ⚠️ Gap | No security groups defined in this stack — presumably handled by tenant provisioner |

## Recommendations

1. **Add CDK assertion tests** — validate synth output without deploying. Low effort, high confidence.
2. **Document the Secrets Manager requirement** for `registry.k8s.io` pull-through cache in new accounts.
3. **Consider documenting the tenant provisioner handoff** — what it expects from this stack beyond SSM params.
