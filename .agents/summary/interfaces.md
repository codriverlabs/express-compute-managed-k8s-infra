# Interfaces

## Inbound Interfaces (Inputs)

### 1. Shell Script Arguments

**`setup-shared-infra.sh`**

| Position | Name | Default | Description |
|----------|------|---------|-------------|
| $1 | REGION | us-east-1 | AWS deployment region |
| $2 | PROJECT_NAME | ecp-managed-k8s-infra | Resource naming prefix |
| $3 | INSTANCE_TYPE_ARM64 | c6g.xlarge | ARM64 instance type |
| $4 | INSTANCE_TYPE_X86 | m7i.large | x86_64 instance type |
| $5 | DISK_SIZE_GB | 20 | Root EBS volume GiB |
| $6 | ENABLE_NAT_GATEWAY | false | NAT gateway toggle |

**`delete-shared-infra.sh`**

| Position | Name | Default | Description |
|----------|------|---------|-------------|
| $1 | REGION | us-east-1 | Region of stack to destroy |
| $2 | PROJECT_NAME | ecp-managed-k8s-infra | Project name (for stack identification) |

### 2. CDK Context (`infra/cdk.json`)

The `parameters` block in `cdk.json` defines default CloudFormation parameter values used during `cdk synth`/`cdk deploy`.

### 3. CloudFormation Parameters

| Parameter | Type | Allowed Values |
|-----------|------|----------------|
| ProjectName | String | — |
| InstanceTypeArm64 | String | — |
| InstanceTypeX86 | String | — |
| DiskSizeGb | Number | — |
| EnableNatGateway | String | `true`, `false` |
| Region | String | — |

### 4. Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| CDK_DEFAULT_ACCOUNT | CDK App | AWS account ID for environment binding |
| CDK_DEFAULT_REGION | setup script | Passed to CDK bootstrap |

## Outbound Interfaces (Outputs)

### SSM Parameter Store

All outputs are written to SSM Parameter Store under the `/express-compute/infra/` namespace:

```mermaid
graph LR
    subgraph "SSM Parameters"
        A["/express-compute/infra/network/vpc-id"]
        B["/express-compute/infra/network/nat-gateway-enabled"]
        C["/express-compute/infra/launch-template/arm64/spot"]
        D["/express-compute/infra/launch-template/arm64/ondemand"]
        E["/express-compute/infra/launch-template/x86_64/spot"]
        F["/express-compute/infra/launch-template/x86_64/ondemand"]
    end

    subgraph "Consumers"
        TP[Tenant Provisioner]
        KP[Karpenter]
    end

    A --> TP
    B --> TP
    C --> KP
    D --> KP
    E --> KP
    F --> KP
```

### Integration Contract

Consumers of this stack must:
1. Read SSM parameters at their deploy/runtime to discover infrastructure IDs
2. Create subnets in the shared VPC (this stack only creates the NAT subnet)
3. Provide their own security groups
4. Attach to the appropriate route table (public or private) based on egress needs

### Tenant Subnet CIDR Allocation

The VPC `10.0.0.0/16` is partitioned as follows:

| CIDR Block | Purpose | AZ |
|------------|---------|-----|
| `10.0.0.0/20` | Reserved for shared infrastructure | — |
| `10.0.16.0/20` | Tenant private subnets (worker nodes) | AZ-a |
| `10.0.32.0/20` | Tenant private subnets (worker nodes) | AZ-b |
| `10.0.48.0/20` | Tenant private subnets (worker nodes) | AZ-c |
| `10.0.64.0/20` | Tenant public subnets (ALB/NLB) | AZ-a |
| `10.0.80.0/20` | Tenant public subnets (ALB/NLB) | AZ-b |
| `10.0.96.0/20` | Tenant public subnets (ALB/NLB) | AZ-c |
| `10.0.128.0/17` | Unallocated (future expansion) | — |

**Rules:**
- Private subnets → attach to the **private route table**
- Public subnets → attach to the **public route table**
- Always provision at least 2 AZs for HA
- Do not allocate from `10.0.0.0/20` (shared infra reserved)

### ECR Pull-Through Cache Prefixes

Container image pulls should reference:
- `{account}.dkr.ecr.{region}.amazonaws.com/public-ecr/{image}` (for public.ecr.aws images)
- `{account}.dkr.ecr.{region}.amazonaws.com/registry-k8s-io/{image}` (for registry.k8s.io images)
- `{account}.dkr.ecr.{region}.amazonaws.com/quay-io/{image}` (for quay.io images)
