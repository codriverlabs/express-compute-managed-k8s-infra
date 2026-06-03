# Review Notes

## Resolved Issues

### ~~1. `setup-shared-infra.sh` referenced wrong CDK directory~~ ✅ Fixed
`CDK_DIR` was set to `"$(dirname "$0")/cdk"`. Changed to `"$(dirname "$0")/infra"`.

### ~~2. `delete-shared-infra.sh` same path issue~~ ✅ Fixed
`cd "$(dirname "$0")/cdk"` changed to `cd "$(dirname "$0")/infra"`.

## Open Gaps

- No private/worker subnet IDs in shared infra — only the NAT subnet (`10.0.0.0/24`) is created here. Worker subnets are provisioned by the tenant project; this inter-repo dependency is undocumented.
- `diskSizeGb` context applies only to the root EBS volume (`/dev/xvda`); the `/dev/sdf` data volume is hardcoded at 20 GiB.
