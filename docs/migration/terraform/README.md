# Migration to Terraform with AMI Builder

## Overview

Migrate from CloudFormation scripts to Terraform with a golden AMI approach, similar to `cloud-workstations-setup`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                               │
│                                                                  │
│  ┌──────────────┐    ┌──────────────────────────────────────┐  │
│  │  AMI Builder │    │         Developer Workstation         │  │
│  │              │    │                                       │  │
│  │  EC2 (temp)  │───▶│  EC2 (persistent)                    │  │
│  │  - EKS-D     │    │  - Pre-installed AMI                 │  │
│  │  - Karpenter │    │  - Karpenter Controller              │  │
│  │  - kubectl   │    │  - User Data: join cluster           │  │
│  └──────┬───────┘    └──────────────────────────────────────┘  │
│         │                                                      │
│         ▼                                                      │
│  ┌──────────────┐                                              │
│  │      SSM     │                                              │
│  │ /workstations/ami/x86_64                                   │
│  └──────────────┘                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
docs/migration/terraform/
├── README.md                    # This file
├── ami-builder/                 # Build golden AMI
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── scripts/
│       └── install.sh           # EKS-D + Karpenter installation
└── terraform/                   # Deploy workstations
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        └── workstation/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

## Two-Phase Deployment

### Phase 1: Build AMI (One-time / On-demand)

```bash
cd ami-builder
terraform init
terraform apply -var="ami_version=v1.0.0"
```

### Phase 2: Deploy Workstation (Per developer)

```bash
cd terraform
terraform init
terraform apply -var="developer_username=alice"
```

## Comparison with Current Setup

| Aspect | Current (CloudFormation) | New (Terraform + AMI) |
|--------|--------------------------|----------------------|
| Boot time | 10-15 min (install EKS-D) | 1-2 min (from AMI) |
| Infrastructure | CloudFormation | Terraform |
| AMI | Not used | Pre-built golden image |
| Karpenter | Script install | Pre-installed |
| Updates | Re-run scripts | Rebuild AMI |

## Migration Steps

1. Create `ami-builder/` - build EKS-D + Karpenter AMI
2. Create `terraform/` - deploy workstations from AMI
3. Migrate VPC (optional - can keep CloudFormation)
4. Update documentation

## See Also

- [cloud-workstations-setup](https://github.com/plasticity-of-cloud/cloud-workstations-setup) - Reference implementation

## Usage

### Build AMI
```bash
cd ami-builder
terraform init
terraform apply \
  -var="ami_version=v1.0.0" \
  -var="aws_region=us-east-1" \
  -var="key_pair_name=my-key" \
  -var="key_file=~/.ssh/my-key.pem"
```

### Deploy Workstation
```bash
cd terraform
terraform init
terraform apply \
  -var="developer_username=alice" \
  -var="aws_region=us-east-1" \
  -var="vpc_id=vpc-xxx" \
  -var="subnet_id=subnet-xxx"
```

## Files

- `ami-builder/main.tf` - EC2 builder that installs EKS-D, Karpenter, kubectl
- `ami-builder/scripts/install.sh` - Installation script run during AMI build
- `terraform/main.tf` - Workstation deployment using AMI from SSM
- `terraform/variables.tf` - Configuration variables
