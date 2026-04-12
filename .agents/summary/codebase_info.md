# Codebase Information

## Overview
- **Project**: ECP Single-Node EKS-D with Karpenter
- **Type**: Infrastructure-as-Code (Shell scripts + CloudFormation + Kubernetes manifests)
- **Purpose**: Deploy self-managed EKS-D clusters on EC2 with Karpenter-managed worker nodes

## Statistics
- **Total Files**: 242
- **Lines of Code**: ~981 (shell scripts)
- **Languages**: Bash, YAML, HCL (Terraform), JSON (CloudFormation)

## Directory Structure

```
ecp-single-node-eks-d/
├── README.md                    # Project overview
├── DEPLOYMENT_GUIDE.md         # Step-by-step deployment
├── cost-estimation.md          # Cost analysis
├── infrastructure/             # CloudFormation + deployment scripts
│   ├── deploy-vpc.sh          # Deploy shared VPC
│   ├── deploy-developer.sh    # Deploy developer EC2 stack
│   ├── developer-stack-template.yaml
│   ├── shared-vpc-template.yaml
│   ├── MANUAL_SETUP.md        # Manual setup instructions
│   ├── DEPLOYMENT.md
│   ├── DEVELOPER_ONBOARDING.md
│   ├── SECURITY.md
│   └── CLOUDFORMATION.md
├── eks-d-setup/               # EKS-D installation scripts
│   ├── install.sh             # Main installer
│   ├── install-all.sh         # Run all installers
│   ├── 01-install-base.sh
│   ├── 02-install-docker.sh
│   ├── 03-install-kubectl.sh
│   ├── 04-install-helm.sh
│   ├── 05-prepare-etcd.sh
│   ├── 06-install-eks-d.sh    # Core EKS-D components
│   ├── 07-install-cni.sh      # CNI networking
│   ├── 08-install-coredns.sh
│   ├── 09-install-ebs-csi.sh
│   ├── 10-configure-node.sh
│   └── 11-install-karpenter.sh
├── karpenter-config/          # Karpenter deployment
│   └── install-karpenter.sh
├── node-pools/                # NodePool definitions
│   ├── configure-nodepools.sh
│   ├── spot-nodepool.yaml
│   ├── ondemand-nodepool.yaml
│   └── test-workload.yaml
├── monitoring/                # CloudWatch monitoring
│   └── cloudwatch-setup.yaml
└── infrastructure/archived/   # Deprecated Terraform files
```

## Technology Stack
- **Cloud**: AWS (EC2, VPC, EBS, CloudWatch, IAM)
- **Kubernetes**: EKS-D (self-managed)
- **Container Runtime**: Docker
- **Orchestration**: Karpenter
- **IaC**: CloudFormation, Bash scripts

## Key Components
1. **EKS-D Control Plane**: API server, etcd, controller manager, scheduler
2. **Karpenter**: Auto-provisioning of worker nodes
3. **VPC**: Shared VPC with private subnets
4. **EC2**: Control plane on dedicated instance per team member
