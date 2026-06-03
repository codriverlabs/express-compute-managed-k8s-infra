# Architecture

## Overview

The repo manages **shared AWS infrastructure** for EKS-DX. All resources are deployed via a single CDK stack. Tenant control plane provisioning (EC2, IAM, SQS) and cluster bootstrap scripts now live in a separate project.

```mermaid
graph TD
    A[setup-shared-infra.sh] -->|cdk deploy| B[EksDxSharedInfraStack]
    B --> C[VPC 10.0.0.0/16]
    B --> D[EC2 Launch Templates x4]
    B --> E[ECR Pull-Through Cache]
    B --> F[S3 Gateway Endpoint]
    B --> G[VPC Flow Logs]
    B --> H[SSM Parameters]
    C --> C1[NAT Subnet 10.0.0.0/24]
    C --> C2[Public Route Table]
    C --> C3[Private Route Table]
    C --> C4[Internet Gateway]
    C --> C5[NAT Gateway optional]
    D --> D1[spot-arm64]
    D --> D2[ondemand-arm64]
    D --> D3[spot-x86_64]
    D --> D4[ondemand-x86_64]
    E --> E1[public.ecr.aws → public-ecr/]
    E --> E2[registry.k8s.io → registry-k8s-io/]
```

## Design Decisions

**NAT Gateway off by default** (`enableNatGateway: false` in `cdk.json`). The S3 gateway endpoint covers the main egress cost driver (ECR image pulls, Karpenter pricing data). NAT can be enabled via context override when outbound internet is needed.

**Launch templates without AMI ID** — `imageId` is intentionally absent. The consuming Lambda/provisioner passes the AMI as a `RunInstances` override. This decouples AMI updates from shared infra changes.

**Spot uses hibernation** — spot LTs set `instanceInterruptionBehavior: hibernate` + `hibernationOptions.configured: true`, requiring EBS root volume encryption (enforced via `encrypted: true`).

**IMDS v2 enforced** — all LTs set `httpTokens: required` and `httpPutResponseHopLimit: 2` (hop limit 2 is needed for containers to reach IMDS).

## CDK Context Defaults (`infra/cdk.json`)

| Key | Default | Notes |
|-----|---------|-------|
| `projectName` | `eks-dx-infra` | Prefix for all resource names |
| `instanceTypeArm64` | `m7g.large` | Used in arm64 launch templates |
| `instanceTypeX86_64` | `m7i.large` | Used in x86_64 launch templates |
| `diskSizeGb` | `20` | Root EBS volume size |
| `enableNatGateway` | `false` | Set to `true` to add NAT GW + EIP |
