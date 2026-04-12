# AGENTS.md - AI Assistant Guide

## Project Overview
ECP Single-Node EKS-D with Karpenter - Infrastructure for deploying self-managed Kubernetes clusters on EC2 with Karpenter-managed worker nodes.

## Directory Overview

```
ecp-single-node-eks-d/
├── infrastructure/           # CloudFormation + deployment scripts
│   ├── deploy-vpc.sh        # Deploy shared VPC
│   ├── deploy-developer.sh  # Deploy per-team-member EC2
│   ├── developer-stack-template.yaml
│   └── shared-vpc-template.yaml
├── eks-d-setup/             # EKS-D installation (numbered scripts)
│   ├── install-all.sh       # Run all installers
│   ├── 06-install-eks-d.sh  # Core Kubernetes components
│   └── 11-install-karpenter.sh
├── karpenter-config/        # Karpenter deployment
│   └── install-karpenter.sh
├── node-pools/              # Karpenter NodePool YAML
│   ├── configure-nodepools.sh
│   ├── spot-nodepool.yaml
│   └── ondemand-nodepool.yaml
└── monitoring/              # CloudWatch setup
    └── cloudwatch-setup.yaml
```

## Key Entry Points

| Task | Command/Script |
|------|----------------|
| Deploy VPC | `cd infrastructure && ./deploy-vpc.sh <region>` |
| Deploy developer EC2 | `./deploy-developer.sh <signum> <num> <keypair> <auto>` |
| Install EKS-D | `./eks-d-setup/install-all.sh` (on EC2) |
| Install Karpenter | `./karpenter-config/install-karpenter.sh` |
| Configure NodePools | `./node-pools/configure-nodepools.sh <signum> [region]` |

## Repo-Specific Patterns

1. **Numbered installation scripts**: `eks-d-setup/` uses numbered prefixes (01-11) for ordered execution
2. **Developer signum**: Team member identifier used in stack names, IAM roles, NodePool tags
3. **CloudFormation over Terraform**: Infrastructure uses CloudFormation (see `infrastructure/archived/` for deprecated Terraform)
4. **Karpenter v1 API**: Uses `karpenter.sh/v1` and `karpenter.k8s.aws/v1` (not v1beta1)

## Configuration Files

- **CloudFormation templates**: YAML format in `infrastructure/`
- **Karpenter NodePools**: YAML in `node-pools/`
- **Monitoring**: YAML in `monitoring/`

## Common Patterns

### Deploy New Developer Environment
```bash
cd infrastructure
./deploy-vpc.sh us-east-1  # If VPC doesn't exist
./deploy-developer.sh alice 1 my-key-pair true
# Wait ~10 min for user data to complete
ssh -i ~/.ssh/my-key-pair.pem ubuntu@<public-ip>
# Verify: kubectl get nodes
```

### Add Worker Nodes
```bash
# Configure Karpenter NodePool
./node-pools/configure-nodepools.sh alice us-east-1

# Apply NodePool
kubectl apply -f node-pools/spot-nodepool.yaml
```

## What to Avoid
- Don't use Terraform (deprecated in `infrastructure/archived/`)
- Don't use Karpenter v1beta1 (use v1)
- Don't skip the numbered order in `eks-d-setup/`

## Custom Instructions
<!-- This section is for human and agent-maintained operational knowledge.
     Add repo-specific conventions, gotchas, and workflow rules here.
     This section is preserved exactly as-is when re-running codebase-summary. -->
