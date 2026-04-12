# Architecture

## System Architecture

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "VPC"
            PublicSubnet[Public Subnet]
            PrivateSubnet[Private Subnet]
            
            subgraph "Developer EC2 Instance"
                EKS-D[("EKS-D Control Plane")]
                Karpenter[Karpenter Controller]
                Kubelet[Kubelet]
            end
            
            WorkerNode[("Karpenter Worker Node<br/>Spot Instance")]
            EBS[("EBS Volumes")]
        end
        
        IAM[IAM Roles]
        SSM[Systems Manager]
    end
    
    Developer["Team Member"]
    
    Developer -->|SSH| PublicSubnet
    Karpenter -->|Provision| WorkerNode
    WorkerNode -->|Join| EKS-D
    EKS-D -->|Store| EBS
    Karpenter -->|IAM| IAM
    EKS-D -->|SSM Parameters| SSM
```

## Component Overview

| Component | Description | Location |
|-----------|-------------|----------|
| **EKS-D Control Plane** | Self-managed Kubernetes control plane (API server, etcd, controller, scheduler) | `eks-d-setup/06-install-eks-d.sh` |
| **Karpenter** | Worker node auto-provisioner | `karpenter-config/`, `eks-d-setup/11-install-karpenter.sh` |
| **VPC** | Shared VPC with public/private subnets | `infrastructure/shared-vpc-template.yaml` |
| **Developer Stack** | Per-team-member EC2 with EKS-D | `infrastructure/deploy-developer.sh` |
| **NodePools** | Karpenter node pool definitions | `node-pools/` |

## Deployment Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant CF as CloudFormation
    participant EC2 as EC2 Instance
    participant EKS as EKS-D
    participant K as Karpenter
    
    Dev->>CF: Deploy VPC
    CF->>Dev: VPC Created
    Dev->>CF: Deploy Developer Stack
    CF->>EC2: Launch EC2 with User Data
    EC2->>EKS: Install EKS-D components
    EC2->>K: Install Karpenter
    Dev->>K: Configure NodePools
    K->>EC2: Provision Spot Worker Nodes
```

## Network Architecture

- **Public Subnet**: NAT Gateway, Bastion (optional)
- **Private Subnet**: EKS-D control plane, worker nodes
- **Security Groups**: Control plane SG, Worker node SG

## Data Flow

1. Developer deploys VPC → CloudFormation
2. Developer deploys EC2 stack → CloudFormation provisions EC2
3. EC2 user data runs `eks-d-setup/install-all.sh`
4. EKS-D control plane starts on EC2
5. Karpenter installed and configured
6. NodePool created → Karpenter provisions Spot instances
7. Worker nodes join cluster via kubelet
