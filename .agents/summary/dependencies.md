# Dependencies

## System Dependencies

| Dependency | Version | Purpose | Install Script |
|------------|---------|---------|----------------|
| Docker | Latest | Container runtime | `eks-d-setup/02-install-docker.sh` |
| kubectl | Latest | Kubernetes CLI | `eks-d-setup/03-install-kubectl.sh` |
| Helm | 3.x | Package manager | `eks-d-setup/04-install-helm.sh` |
| AWS CLI | Latest | AWS interactions | (system package) |

## External Services

| Service | Purpose | Configuration |
|---------|---------|---------------|
| AWS EC2 | Compute instances | Via CloudFormation |
| AWS VPC | Networking | Via CloudFormation |
| AWS IAM | Access control | Instance roles |
| AWS EBS | Persistent storage | Via EBS CSI Driver |
| AWS CloudWatch | Monitoring | Via cloudwatch-setup.yaml |

## Kubernetes Components

| Component | Version | Purpose |
|-----------|---------|---------|
| EKS-D | Latest | Kubernetes distribution |
| VPC CNI | Latest | Networking |
| CoreDNS | Latest | DNS service |
| EBS CSI Driver | Latest | Storage |
| Karpenter | Latest | Node auto-provisioning |

## Installation Order

1. **Base**: Docker, kubectl, helm
2. **etcd**: Prepare data directory
3. **EKS-D**: API server, controller, scheduler
4. **Networking**: CNI, CoreDNS
5. **Storage**: EBS CSI Driver
6. **Karpenter**: Controller, NodePool
