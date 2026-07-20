# Components

## SharedInfraStack

The single CDK stack containing all shared infrastructure. Located in `infra/src/main/java/cloud/plasticity/ecp/SharedInfraStack.java`.

### Networking (`createNetworking`)

Creates the VPC foundation:
- VPC `10.0.0.0/16` with DNS hostnames/support
- Internet Gateway + VPC attachment
- NAT subnet `10.0.0.0/24` in first AZ (public, map-public-IP)
- Conditional NAT Gateway + EIP (only if `enableNatGateway=true`)
- Public route table (default route → IGW)
- Private route table (default route → NAT if enabled)

Returns a `Networking` record with `vpcId`, `publicRtId`, `privateRtId`.

### VPC Flow Logs (`createFlowLogs`)

- CloudWatch log group: `/aws/vpc/{region}/{projectName}-flow-logs`
- Retention: 1 week
- Removal policy: DESTROY
- Dedicated IAM role for vpc-flow-logs service

### ECR Pull-Through Cache (`createEcrPullThroughCache`)

Three cache rules (all L1 — no L2 exists):

| Prefix | Upstream |
|--------|----------|
| `public-ecr/` | `public.ecr.aws` |
| `registry-k8s-io/` | `registry.k8s.io` |
| `quay-io/` | `quay.io` |

### S3 Gateway Endpoint (`createS3Endpoint`)

- Type: Gateway (free, no NAT cost for S3 traffic)
- Service: `com.amazonaws.{region}.s3`
- Attached to both public and private route tables

### Launch Templates (`createLaunchTemplates`)

4 templates generated from a `LtConfig` record cross-product:

| Template | Arch | Market | Instance Type |
|----------|------|--------|---------------|
| `{project}-spot-arm64` | arm64 | spot (hibernate) | from context |
| `{project}-ondemand-arm64` | arm64 | on-demand | from context |
| `{project}-spot-x86_64` | x86_64 | spot (hibernate) | from context |
| `{project}-ondemand-x86_64` | x86_64 | on-demand | from context |

Common settings:
- IMDS v2 required (hop limit 2)
- `/dev/xvda`: gp3, encrypted, `diskSizeGb` from context
- `/dev/sdf`: gp3, encrypted, fixed 20 GiB
- No AMI ID (passed at RunInstances time)
- Instance + volume tags for tracking

Each LT ID is published to SSM.

### Network SSM Parameters (`createNetworkSsmParams`)

| Parameter | Value |
|-----------|-------|
| `/express-compute/infra/network/vpc-id` | VPC ID |
| `/express-compute/infra/network/nat-gateway-enabled` | `true` or `false` |

## EcpManagedK8sInfraApp

CDK App entry point (`EcpManagedK8sInfraApp.java`). Reads `CDK_DEFAULT_ACCOUNT` and `CDK_DEFAULT_REGION` from environment, instantiates `SharedInfraStack`.

## Shell Scripts

| Script | Purpose |
|--------|---------|
| `setup-shared-infra.sh` | Bootstrap CDK → compile → synth → deploy |
| `delete-shared-infra.sh` | `cdk destroy --force` |

Both accept `[region] [projectName]` positional args with defaults.
