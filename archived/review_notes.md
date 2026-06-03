# Review Notes

## Consistency Issues

### 1. `setup-shared-infra.sh` references wrong CDK directory
`setup-shared-infra.sh` line 14 sets `CDK_DIR="$(dirname "$0")/cdk"` but the CDK project was renamed from `cdk/` to `infra/`. Maven is invoked with `-f "${CDK_DIR}/pom.xml"` (wrong path). The `cd "${CDK_DIR}"` for `cdk synth`/`cdk deploy` also targets the old path.

**Fix needed**: Change `CDK_DIR="$(dirname "$0")/cdk"` → `CDK_DIR="$(dirname "$0")/infra"`.

### 2. `delete-shared-infra.sh` same path issue
Line 21: `cd "$(dirname "$0")/cdk"` → should be `"$(dirname "$0")/infra"`.

## Completeness Gaps

- No subnet IDs for private/worker subnets — the stack creates only the NAT subnet. Worker subnets are presumably created by the tenant provisioner in the sibling project. This inter-repo dependency is undocumented.
- No security group for the shared infra — SGs are presumably created per-tenant in the sibling project.
- `diskSizeGb` context applies only to the root EBS volume in launch templates; the `/dev/sdf` data volume is hardcoded at 20 GiB.

## Language Support Notes

All active code is Java (CDK) and Bash. No limitations from language support.
