# Architecture

## System Context

```mermaid
graph TB
    subgraph "Express Compute Platform"
        INFRA["EcpManagedK8sInfraStack<br/>(this project)"]
        TENANT["Tenant Provisioner<br/>(separate project)"]
        KARPENTER["Karpenter"]
    end

    subgraph "AWS Services"
        VPC["VPC 10.0.0.0/16"]
        ECR["ECR Pull-Through Cache"]
        S3EP["S3 Gateway Endpoint"]
        SSM["SSM Parameter Store"]
        CW["CloudWatch Logs"]
    end

    INFRA --> VPC
    INFRA --> ECR
    INFRA --> S3EP
    INFRA --> SSM
    INFRA --> CW

    TENANT -->|reads LT IDs, VPC ID| SSM
    KARPENTER -->|uses LTs| VPC
    TENANT -->|launches instances| VPC
```

## Stack Composition

```mermaid
graph LR
    subgraph SharedInfraStack
        NET["createNetworking()"]
        FL["createFlowLogs()"]
        ECR["createEcrPullThroughCache()"]
        S3["createS3Endpoint()"]
        LT["createLaunchTemplates()"]
        SSM["createNetworkSsmParams()"]
    end

    NET --> FL
    NET --> S3
    NET --> SSM
    LT --> SSM
```

## Network Architecture

```mermaid
graph TB
    subgraph "VPC 10.0.0.0/16"
        subgraph "NAT Subnet 10.0.0.0/24 (public)"
            NAT["NAT Gateway<br/>(optional)"]
        end
        IGW["Internet Gateway"]
        PUB_RT["Public Route Table<br/>0.0.0.0/0 → IGW"]
        PRIV_RT["Private Route Table<br/>0.0.0.0/0 → NAT (if enabled)"]
        S3EP["S3 Gateway Endpoint<br/>(both RTs)"]
    end

    IGW --> PUB_RT
    NAT --> PRIV_RT
    S3EP --> PUB_RT
    S3EP --> PRIV_RT
```

## Design Patterns

| Pattern | Usage |
|---------|-------|
| L1 Constructs (CfnXxx) | VPC, LTs, ECR cache — fine-grained control needed |
| L2 Constructs | LogGroup, Role — higher-level abstractions sufficient |
| SSM Parameter Discovery | Outputs published to SSM for decoupled consumer access |
| Context-driven Configuration | All tunables passed via CDK context, not hardcoded |
| Conditional Resources | NAT Gateway + EIP only created when `enableNatGateway=true` |
| Record Types | `Networking`, `LtConfig` — lightweight internal data carriers |
