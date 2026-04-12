# Components

## Core Components

### 1. EKS-D Control Plane
- **Description**: Self-managed Kubernetes control plane
- **Files**: `eks-d-setup/06-install-eks-d.sh`
- **Components**:
  - kube-apiserver
  - kube-controller-manager
  - kube-scheduler
  - etcd
  - kubelet

### 2. Karpenter
- **Description**: Kubernetes node auto-provisioner
- **Files**: 
  - `karpenter-config/install-karpenter.sh`
  - `eks-d-setup/11-install-karpenter.sh`
  - `node-pools/configure-nodepools.sh`
- **Resources**:
  - EC2NodeClass
  - NodePool (Spot, On-Demand)

### 3. VPC Infrastructure
- **Description**: AWS networking
- **Files**: 
  - `infrastructure/shared-vpc-template.yaml`
  - `infrastructure/deploy-vpc.sh`

### 4. Developer Stack
- **Description**: Per-team-member EC2 instance
- **Files**:
  - `infrastructure/deploy-developer.sh`
  - `infrastructure/developer-stack-template.yaml`

### 5. CNI & Networking
- **Files**:
  - `eks-d-setup/07-install-cni.sh` - VPC CNI
  - `eks-d-setup/08-install-coredns.sh` - CoreDNS

### 6. Storage
- **Files**: `eks-d-setup/09-install-ebs-csi.sh` - EBS CSI Driver

## Supporting Components

| Component | Purpose | File |
|-----------|---------|------|
| Docker | Container runtime | `eks-d-setup/02-install-docker.sh` |
| kubectl | Kubernetes CLI | `eks-d-setup/03-install-kubectl.sh` |
| Helm | Package manager | `eks-d-setup/04-install-helm.sh` |
| CloudWatch | Monitoring | `monitoring/cloudwatch-setup.yaml` |

## Component Relationships

```mermaid
classDiagram
    class DeveloperStack {
        +EC2 Instance
        +EKS-D Control Plane
        +Karpenter Controller
    }
    
    class NodePool {
        +EC2NodeClass
        +NodePool spec
    }
    
    class VPC {
        +Public Subnet
        +Private Subnet
        +Security Groups
    }
    
    DeveloperStack --> VPC: Uses network
    DeveloperStack --> NodePool: Creates
    NodePool --> VPC: Provisions nodes in
