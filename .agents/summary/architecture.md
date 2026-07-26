# Architecture

## Overview

The system is a single AWS CDK stack that provisions shared infrastructure for the Express Compute platform. It follows a "shared-nothing per tenant" philosophy where this stack creates the common network and compute primitives, and separate tenant provisioning systems consume outputs via SSM Parameter Store.

## Architecture Diagram

```mermaid
graph TB
    subgraph "CDK App"
        App[EcpManagedK8sInfraApp]
        Stack[ExpressComputeManagedK8sInfraStack]
        App --> Stack
    end

    subgraph "AWS Resources"
        subgraph "Networking"
            VPC[VPC 10.0.0.0/16]
            IGW[Internet Gateway]
            NAT[NAT Gateway<br/>conditional]
            PubRT[Public Route Table]
            PrivRT[Private Route Table]
            NATSubnet[NAT Subnet<br/>10.0.0.0/24]
        end

        subgraph "Compute"
            LT_ARM_SPOT[LT: arm64 spot]
            LT_ARM_OD[LT: arm64 on-demand]
            LT_X86_SPOT[LT: x86_64 spot]
            LT_X86_OD[LT: x86_64 on-demand]
        end

        subgraph "Container Registry"
            ECR_PUB[ECR Cache: public.ecr.aws]
            ECR_K8S[ECR Cache: registry.k8s.io]
            ECR_QUAY[ECR Cache: quay.io]
        end

        subgraph "Connectivity"
            S3EP[S3 Gateway Endpoint]
        end

        subgraph "Observability"
            FlowLog[VPC Flow Log]
            LogGroup[CloudWatch Log Group<br/>1-week retention]
            FlowRole[Flow Logs IAM Role]
        end

        subgraph "Discovery"
            SSM_VPC[SSM: vpc-id]
            SSM_NAT[SSM: nat-gateway-enabled]
            SSM_LT1[SSM: LT arm64/spot]
            SSM_LT2[SSM: LT arm64/ondemand]
            SSM_LT3[SSM: LT x86_64/spot]
            SSM_LT4[SSM: LT x86_64/ondemand]
        end
    end

    VPC --> IGW
    VPC --> NAT
    VPC --> PubRT
    VPC --> PrivRT
    NATSubnet --> PubRT
    FlowLog --> LogGroup
    FlowLog --> FlowRole
    S3EP --> PubRT
    S3EP --> PrivRT
```

## Design Principles

1. **L1-only constructs** — All resources use `Cfn*` classes for full CloudFormation control. No L2/L3 abstractions are used, ensuring the synthesized template is predictable and auditable.

2. **Region-agnostic synthesis** — The CDK app omits region from the Environment, and passes region as a CloudFormation parameter. This allows one synthesized `cdk.out` to be deployed to any region.

3. **Conditional resources** — The NAT gateway and its associated EIP/route are guarded by a `CfnCondition`, so they are only created when explicitly enabled.

4. **SSM as service discovery** — All consumer-facing resource IDs are published to SSM Parameter Store under a well-known path prefix (`/express-compute/infra/`), decoupling this stack from consumers.

5. **Security defaults** — IMDSv2 required, EBS encryption enabled, no AMI baked in (Karpenter provides AMIs at runtime).

## Deployment Model

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Script as setup-shared-infra.sh
    participant CDK as CDK CLI
    participant CFN as CloudFormation
    participant AWS as AWS Resources

    Dev->>Script: ./setup-shared-infra.sh us-east-1
    Script->>CDK: cdk bootstrap
    Script->>CDK: mvn compile
    Script->>CDK: cdk synth
    Script->>CDK: cdk deploy --parameters ...
    CDK->>CFN: Create/Update stack
    CFN->>AWS: Provision resources
    AWS-->>CFN: Resource IDs
    CFN-->>CDK: Stack outputs
    CDK-->>Script: Deploy complete
```

## Consumer Interaction

```mermaid
graph LR
    subgraph "This Stack"
        SSM[SSM Parameters]
    end

    subgraph "Tenant Provisioner (separate repo)"
        TP[Tenant Control Plane]
    end

    subgraph "Karpenter"
        KP[Node Provisioner]
    end

    SSM -->|vpc-id| TP
    SSM -->|launch-template IDs| KP
```
