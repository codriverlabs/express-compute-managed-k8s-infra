# Architecture

## Overview

A single CDK stack (`EksDxSharedInfraStack`) that provisions all shared AWS resources consumed by EKS-DX tenant control planes. Tenants read VPC and launch template IDs from SSM; they do not interact with this repo directly.

```mermaid
graph TB
    subgraph CDK["EksDxSharedInfraStack"]
        VPC["VPC 10.0.0.0/16\n+ IGW + subnets + route tables"]
        S3EP["S3 Gateway Endpoint"]
        ECR["ECR Pull-Through Cache\npublic-ecr / registry-k8s-io"]
        FL["VPC Flow Logs → CloudWatch"]
        LT["4 Launch Templates\n(spot+ondemand) × (arm64+x86_64)"]
        SSM["SSM Parameters\nvpc-id + 4 LT IDs"]
    end

    VPC --> S3EP
    VPC --> FL
    VPC --> SSM
    LT --> SSM

    subgraph Consumers
        Karpenter["Karpenter\n(tenant)"]
        Lambda["Tenant provisioner\n(separate project)"]
    end

    SSM --> Karpenter
    SSM --> Lambda
    ECR --> Karpenter
```

## Design Principles

- **L1 constructs only where no L2 exists** — ECR pull-through cache rules use `CfnPullThroughCacheRule` directly; all other resources use CDK L2/L3 where available.
- **No AMI in launch templates** — AMI is passed as a `RunInstances` override by the tenant provisioner, decoupling AMI updates from shared infra deployments.
- **NAT optional** — S3 gateway endpoint covers the primary egress cost driver (ECR image pulls). NAT Gateway is disabled by default and opt-in via `enableNatGateway` context.
- **SSM as contract** — all consumer-facing outputs are SSM parameters, not CloudFormation exports, so tenants can read them without cross-stack dependencies.
- **All resources tagged** with `Project`, `Platform: eks-d-xpress`, and `ManagedBy: CDK|Karpenter`.

## Network Layout

```mermaid
graph LR
    subgraph VPC["VPC 10.0.0.0/16"]
        NATSubnet["NAT subnet 10.0.0.0/24\n(mapPublicIpOnLaunch=true)"]
        PublicRT["Public RT\n0.0.0.0/0 → IGW"]
        PrivateRT["Private RT\n0.0.0.0/0 → NAT GW (if enabled)"]
    end
    IGW["Internet Gateway"]
    NAT["NAT Gateway\n(optional)"]

    IGW --> NATSubnet
    NATSubnet --> PublicRT
    PrivateRT -.->|"enableNatGateway=true"| NAT
    NAT --> IGW
```

No private subnets are created by the stack — tenant subnets are provisioned by the tenant provisioner using this VPC ID.
