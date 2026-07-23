# Components

## ExpressComputeManagedK8sInfraStack

The single CDK stack containing all shared infrastructure. Located at `infra/src/main/java/ai/codriverlabs/ecp/ExpressComputeManagedK8sInfraStack.java`.

### CloudFormation Parameters

All runtime configuration is received via CfnParameter (not CDK context):

| Parameter | Type | Description |
|-----------|------|-------------|
| `ProjectName` | String | Resource naming prefix |
| `InstanceTypeArm64` | String | ARM instance type |
| `InstanceTypeX86` | String | x86 instance type |
| `DiskSizeGb` | Number | Root EBS volume size (GiB) |
| `EnableNatGateway` | String | `true` or `false` (drives CfnCondition) |
| `Region` | String | AWS region (passed explicitly at deploy time) |

### Networking (`createNetworking`)

Creates the VPC foundation:
- VPC `10.0.0.0/16` with DNS hostnames/support
- Internet Gateway + VPC attachment
- NAT subnet `10.0.0.0/24` in first AZ (public, map-public-IP)
- Conditional NAT Gateway + EIP (only if `EnableNatGateway=true`, controlled by `CfnCondition`)
- Public route table (default route → IGW)
- Private route table (default route → NAT if enabled)

Returns a `Networking` record with `vpcId`, `publicRtId`, `privateRtId`.

### VPC Flow Logs (`createFlowLogs`)

- CloudWatch log group: `/aws/vpc/{region}/{projectName}-flow-logs`
- Retention: 1 week
- Removal policy: DESTROY
- Dedicated IAM role for `vpc-flow-logs.amazonaws.com` service

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
| `{project}-spot-arm64-{region}` | arm64 | spot (hibernate) | from parameter |
| `{project}-ondemand-arm64-{region}` | arm64 | on-demand | from parameter |
| `{project}-spot-x86_64-{region}` | x86_64 | spot (hibernate) | from parameter |
| `{project}-ondemand-x86_64-{region}` | x86_64 | on-demand | from parameter |

Common settings:
- IMDS v2 required (hop limit 2)
- `/dev/xvda`: gp3, encrypted, `diskSizeGb` from parameter
- `/dev/sdf`: gp3, encrypted, fixed 20 GiB
- No AMI ID (passed at RunInstances time)
- Instance tags: `Platform=express-compute`, `Arch`, `ManagedBy=Karpenter`
- Volume tags: `Platform=express-compute`, `ManagedBy=CDK`
- Launch template tags: `Name`, `Platform`, `Arch`, `Mode`, `ManagedBy=CDK`

Each LT ID is published to SSM.

### Network SSM Parameters (`createNetworkSsmParams`)

| Parameter | Value |
|-----------|-------|
| `/express-compute/infra/network/vpc-id` | VPC ID |
| `/express-compute/infra/network/nat-gateway-enabled` | `true` or `false` |

## EcpManagedK8sInfraApp

CDK App entry point (`EcpManagedK8sInfraApp.java`). Reads `CDK_DEFAULT_ACCOUNT` from environment; region intentionally omitted from `Environment` so the synthesized template is deployable to any region at runtime.

## Shell Scripts

| Script | Purpose | Args |
|--------|---------|------|
| `setup-shared-infra.sh` | Bootstrap CDK → compile → synth → deploy | `[region] [projectName] [instanceTypeArm64] [instanceTypeX86] [diskSizeGb] [enableNatGateway]` |
| `delete-shared-infra.sh` | `cdk destroy --force` | `[region] [projectName]` |
