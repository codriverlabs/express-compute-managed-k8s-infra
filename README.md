# ECP Single-Node EKS-D with Karpenter

## Architecture Overview

Each team member gets a dedicated EC2 instance running EKS-D as the control plane, with Karpenter managing worker nodes as Spot instances.

```
Team Member EC2 (On-Demand + Compute Savings Plan)
├── EKS-D Control Plane
│   ├── API Server
│   ├── etcd
│   ├── Controller Manager
│   └── Scheduler
└── Karpenter Controller
    └── Provisions Spot Worker Nodes via NodePools
```

## Benefits

- **Cost Optimized**: Control plane on Compute Savings Plan, workers on Spot
- **Individual Environments**: Each team member has isolated cluster
- **Full Karpenter**: Complete EC2 integration and cost optimization
- **Scalable**: Workers scale to zero when not needed

## Directory Structure

```
ecp-single-node-eks-d/
├── README.md                    # This file
├── infrastructure/              # Terraform for EC2 setup
├── eks-d-setup/                # EKS-D installation scripts
├── karpenter-config/           # Karpenter deployment configs
├── node-pools/                 # NodePool definitions
├── iam-policies/               # Required IAM configurations
├── networking/                 # VPC and security group configs
└── monitoring/                 # CloudWatch and logging setup
```

## Quick Start

1. **Deploy Infrastructure**: `cd infrastructure && terraform apply`
2. **Install EKS-D**: `cd eks-d-setup && ./install.sh`
3. **Deploy Karpenter**: `cd karpenter-config && kubectl apply -f .`
4. **Create NodePools**: `cd node-pools && kubectl apply -f spot-nodepool.yaml`

## Cost Estimation

- **Control Plane**: ~$50-100/month per team member (with Compute Savings Plan)
- **Worker Nodes**: Pay only when running, ~60-90% savings with Spot
- **Storage**: EBS volumes for etcd and container images

## Next Steps

See individual directories for detailed setup instructions.
