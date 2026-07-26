# Express Compute Infra — Shared Infrastructure

Shared AWS infrastructure for the Express Compute platform for express Kubernetes deployments, first release includes eks-d-xpress. Deployed as a single AWS CDK stack. Provisions the VPC, EC2 launch templates, ECR pull-through cache, and S3 endpoint used by all Express Compute tenants.

> Tenant control plane provisioning (EC2, IAM, SQS, cluster bootstrap) lives in a separate project.

## What This Deploys

- **VPC** `10.0.0.0/16` — IGW, NAT subnet, public + private route tables
- **S3 Gateway Endpoint** — keeps ECR pulls and Karpenter pricing data off NAT
- **ECR Pull-Through Cache** — `public.ecr.aws` and `registry.k8s.io` mirrored into your account ECR
- **4 EC2 Launch Templates** — (spot + on-demand) × (arm64 + x86_64), IMDS v2, encrypted EBS, no AMI ID
- **VPC Flow Logs** — CloudWatch, 1-week retention
- **SSM Parameters** — VPC ID + all 4 LT IDs published for consumers

## Usage

```bash
# Deploy
./setup-shared-infra.sh [region] [projectName]

# Destroy
./delete-shared-infra.sh [region] [projectName]
```

Defaults: `region=us-east-1`, `projectName=ecp-managed-k8s-infra`.

## Prerequisites

- AWS CLI configured
- CDK CLI (`npm i -g aws-cdk`)
- Java 21 + Maven 3

## Configuration

All options can be customized in two ways:

1. **Edit `infra/cdk.json`** — changes the defaults permanently for all future deploys.
2. **Pass `--context` flags** at deploy time — overrides defaults without modifying files.

### Available Options

| Key | Default | Notes |
|-----|---------|-------|
| `projectName` | `ecp-managed-k8s-infra` | Used in resource names and SSM paths |
| `instanceTypeArm64` | `c6g.xlarge` | Must support hibernation (spot LTs) |
| `instanceTypeX86_64` | `m7i.large` | Must support hibernation (spot LTs) |
| `diskSizeGb` | `20` | Root EBS volume size in GiB |
| `enableNatGateway` | `false` | Enable if workers need general internet egress |

### Overriding at Deploy Time

```bash
# Override instance types and enable NAT
cd infra
cdk deploy ExpressComputeManagedK8sInfraStack \
  --context instanceTypeArm64=m7g.xlarge \
  --context enableNatGateway=true \
  --require-approval never
```

Or using the convenience script (supports `projectName` and `region` only):

```bash
./setup-shared-infra.sh us-west-2 my-custom-project
```

For additional context overrides with the script, edit `infra/cdk.json` before running.

## Tenant Subnet Allocation

This stack creates the VPC (`10.0.0.0/16`) but only provisions one subnet — the NAT subnet (`10.0.0.0/24` in AZ-a). Tenant provisioners are responsible for creating their own subnets within the VPC.

### CIDR Allocation Map

```
10.0.0.0/16 (VPC)
│
├── 10.0.0.0/20   — Reserved for shared infrastructure
│   ├── 10.0.0.0/24   — NAT subnet (AZ-a, created by this stack)
│   └── 10.0.1.0/24 … 10.0.15.255 — reserved for future shared use
│
├── 10.0.16.0/20  — Tenant private subnets, AZ-a (4,094 IPs)
├── 10.0.32.0/20  — Tenant private subnets, AZ-b (4,094 IPs)
├── 10.0.48.0/20  — Tenant private subnets, AZ-c (4,094 IPs)
│
├── 10.0.64.0/20  — Tenant public subnets, AZ-a (for ALB/NLB)
├── 10.0.80.0/20  — Tenant public subnets, AZ-b
├── 10.0.96.0/20  — Tenant public subnets, AZ-c
│
└── 10.0.128.0/17 — Unallocated (future expansion)
```

### Guidelines for Tenant Provisioners

1. **Private subnets** (worker nodes): Use `10.0.16.0/20`, `10.0.32.0/20`, `10.0.48.0/20` — one per AZ. Attach to the **private route table** exported by this stack.
2. **Public subnets** (load balancers): Use `10.0.64.0/20`, `10.0.80.0/20`, `10.0.96.0/20` — one per AZ. Attach to the **public route table**.
3. **Multi-AZ**: Always create subnets in at least 2 AZs for high availability. Use `Fn::GetAZs` to select AZs dynamically.
4. **Route table association**: Read the VPC ID from SSM (`/express-compute/infra/network/vpc-id`). Discover route tables via VPC tags or add new SSM parameters if needed.
5. **Do not use** `10.0.0.0/20` — this range is reserved for shared infrastructure.

### NAT Egress

- When `EnableNatGateway=false` (default): private subnets have **no internet egress**. S3 is reachable via the gateway endpoint.
- When `EnableNatGateway=true`: the private route table has a default route through NAT. All private subnets associated with it get internet egress.

## SSM Outputs

| Path | Value |
|------|-------|
| `/express-compute/infra/network/vpc-id` | VPC ID |
| `/express-compute/infra/network/nat-gateway-enabled` | `true` or `false` |
| `/express-compute/infra/launch-template/{arch}/{spot\|ondemand}` | Launch template ID |

## Directory Structure

```
express-compute-infra/
├── setup-shared-infra.sh
├── delete-shared-infra.sh
├── infra/
│   ├── cdk.json
│   ├── pom.xml
│   └── src/main/java/cloud/plasticity/ecp/
│       ├── EcpManagedK8sInfraApp.java
│       └── SharedInfraStack.java
└── archived/           # Legacy Terraform + eks-d-setup scripts
```
