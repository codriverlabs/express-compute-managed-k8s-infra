# Architecture

## Overview

EKS-D-Xpress (EKS-DX) provisions isolated developer Kubernetes environments, part of the Express Compute (ECP) product suite. Each developer gets a dedicated EC2 instance running EKS-D as a single-node control plane, with Karpenter provisioning Spot/On-Demand worker nodes on demand.

```mermaid
graph TB
    subgraph "Shared Infrastructure"
        VPC["Shared VPC\neks-dx-shared-vpc"]
        S3["S3 Bucket\neks-dx-tfstate-{account}"]
        IGW["Internet Gateway"]
        NAT["NAT Gateway"]
    end

    subgraph "Per-Developer Stack"
        subgraph "Public Subnet 10.0.N.0/24"
            WS["Workstation EC2\nalice-eks-dx-arm64\nm6g.large / m6i.xlarge"]
        end
        subgraph "Private Subnet 10.0.(100+N).0/24"
            W1["Worker Node\n(Spot/On-Demand)"]
            W2["Worker Node\n(Spot/On-Demand)"]
        end
        SQS["SQS Queue\nalice-eks-dx\n(Karpenter interruption)"]
        IAM["IAM Role\neks-dx-workstation-alice\n(shared by control plane + workers)"]
    end

    subgraph "Workstation EC2"
        API["kube-apiserver\n:6443"]
        ETCD["etcd\n/dev/sdf (20GB gp3)"]
        CCM["AWS Cloud Controller Manager"]
        KARP["Karpenter v1.10.0\n(kube-system)"]
        AUTH["aws-iam-authenticator\n(static pod :21362)"]
    end

    VPC --> WS
    VPC --> W1
    VPC --> W2
    IGW --> VPC
    NAT --> VPC
    WS --> SQS
    WS --> IAM
    W1 --> IAM
    W2 --> IAM
    KARP --> SQS
    API --> AUTH
```

## Two Deployment Paths

```mermaid
flowchart LR
    subgraph "AMI Path (recommended)"
        A1[build.sh] --> A2[Custom AMI\npre-pulled images]
        A2 --> A3[deploy.sh]
        A3 --> A4[EC2 first boot\nworkstation-boot.sh]
        A4 --> A5[Cluster ready\n~5 min]
    end

    subgraph "Fresh Install Path"
        B1[deploy.sh] --> B2[EC2 launched]
        B2 --> B3[SSH + install-all.sh]
        B3 --> B4[Cluster ready\n~30 min]
    end
```

## Networking

- **Shared VPC**: One per region, shared across all developers
- **Per-developer subnets**: Public (`10.0.N.0/24`) + Private (`10.0.(100+N).0/24`), auto-indexed
- **Workstation**: Deployed in public subnet (SSH access, Kubernetes API on :6443)
- **Worker nodes**: Deployed in private subnet (tagged `SubnetType=Private`, `Developer=<signum>`)
- **Pod networking**: AWS VPC CNI — pods get VPC IPs from secondary ENIs
- **ec2-net-utils**: Disabled on AL2023 before VPC CNI install (conflicts with pod routing)

## IAM Design

The control plane EC2 and all Karpenter-provisioned worker nodes share a single IAM role (`eks-dx-workstation-<username>`). This role carries:
- Managed policies: SSM, ECR pull, EKS CNI, EBS CSI, CloudWatch
- Inline policy `eks-dx-karpenter`: EC2/SQS permissions for Karpenter (tag-scoped)
- Inline policy `eks-dx-cloud-provider`: EC2/ELB permissions for AWS CCM (tag-scoped)

Worker node authentication uses `aws-iam-authenticator` (static pod), which maps the shared IAM role to `system:node:{{EC2PrivateDNSName}}` in `system:nodes` group — satisfying the Node Authorizer without any additional role mapping.

## Karpenter on EKS-D (non-EKS)

Key differences from standard EKS Karpenter setup:
- `settings.eksControlPlane=false` — disables EKS DescribeCluster calls
- `settings.clusterEndpoint` set explicitly to `https://<private-ip>:6443`
- `amiFamily: Custom` (not `AL2023`) — avoids Karpenter v1.10 bug where `ResolveClusterCIDR` always runs for AL2023 regardless of `eksControlPlane=false`
- Worker node bootstrap uses `nodeadm` (AL2023 EKS-Optimized AMI) with explicit `NodeConfig` (cluster name, API endpoint, CA bundle, service CIDR)
- Helm chart pulled from OCI registry (`public.ecr.aws/karpenter/karpenter`) — `helm repo add` does not work
