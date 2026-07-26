# Review Notes

## Consistency Check

✅ **PASS** — All documentation files reference consistent:
- Parameter names (ProjectName, InstanceTypeArm64, etc.)
- SSM paths (`/express-compute/infra/...`)
- Resource naming patterns (`{project}-{resource}-{region}`)
- Architecture descriptions (L1-only, region-agnostic, conditional NAT)

No inconsistencies detected across documents.

## Completeness Check

### Well-Documented Areas
- ✅ VPC networking topology and conditional NAT behavior
- ✅ Launch template configuration and spot/hibernation strategy
- ✅ Deploy and destroy workflows
- ✅ SSM parameter contract for consumers
- ✅ CI/CD release process
- ✅ Dependency management strategy

### Gaps Identified

| Area | Gap | Impact | Recommendation |
|------|-----|--------|----------------|
| Testing | No unit or integration tests exist in the repo | Medium | Add CDK assertion tests (`@aws-cdk/assertions`) to validate synthesized template |
| Multi-region | No documentation of multi-region deployment patterns | Low | Document if/how multiple regions are deployed (serial runs of setup script) |
| Tenant integration | Consumer contract is described but no example consumer code | Low | Add example snippet showing SSM parameter reads from tenant provisioner |
| Security | IAM role for flow logs uses `Resource: *` | Low | Consider scoping to the specific log group ARN |
| Monitoring | No CloudWatch alarms or dashboards defined | Low | Consider adding alarms for flow log delivery failures |
| Subnet strategy | Only NAT subnet is created; consumer subnet creation is undocumented | Medium | Document expected subnet CIDR allocation for tenants |
| Backup/DR | No documentation of disaster recovery or cross-region replication | Low | Document recovery procedure (re-run setup script) |

### Language Support

- ✅ Java 21 — fully analyzed
- ✅ Shell (bash) — fully analyzed
- ✅ YAML (CI/CD, config) — fully analyzed
- N/A — No unsupported languages detected

## Recommendations

1. **Add CDK assertion tests** — The project has zero test coverage. `cdk-assertions` would catch template regressions.
2. **Scope flow logs IAM policy** — Replace `Resource: *` with the specific log group ARN for least-privilege.
3. **Document tenant subnet allocation** — Consumers need to know which CIDRs are available for their subnets within the `/16`.
4. **Consider adding a second AZ** — The NAT subnet is single-AZ; if tenants need multi-AZ, document how they should handle this.
