# EKS-D-Xpress — Express Compute

## Architecture Overview

Each tenant gets a dedicated EC2 instance running EKS-D as the control plane, with Karpenter managing Spot worker nodes on demand.

```
Tenant Control Plane EC2
├── EKS-D Control Plane (kubeadm, EKS-D images)
│   ├── API Server + aws-iam-authenticator webhook
│   ├── etcd (dedicated EBS volume)
│   ├── Controller Manager / Scheduler
│   └── AWS VPC CNI + Cloud Controller Manager
└── Karpenter Controller
    └── Provisions Spot Worker Nodes via NodePools
```

## Script Execution Sequence

### 1. One-time account setup
```bash
./bootstrap.sh [region]
```
Creates Terraform state S3 bucket and provisions shared infrastructure (VPC, subnets, route tables, NAT gateway).

### 2. Build control plane AMI
```bash
./build-control-plane-ami.sh
```
Packer builds a custom AMI with all binaries, container images, and Helm charts pre-baked. Stores AMI ID in SSM at `/eks-dx/ami/<region>/<k8s-version>/<arch>`. Takes ~15-20 min. Must be run before provisioning tenants.

### 3. Provision tenant
```bash
./provision-tenant.sh
```
Terraform creates per-tenant resources: IAM role + instance profile, security group, subnets, SQS queue (Karpenter interruption), EventBridge rules, and launches the control plane EC2 instance. EC2 boots and automatically runs `workstation-boot.sh` → `setup-eks-d.sh`. Cluster ready in ~3 min.

### 4. Configure NodePool (on the control plane EC2)
```bash
./node-pools/configure-nodepools.sh <tenant-id> [region]
```
Discovers runtime values (AMI ID, subnet, SG, CA bundle) and applies Karpenter NodePool + EC2NodeClass.

### Teardown
```bash
./deprovision-tenant.sh        # Destroy single tenant
./deprovision-shared-infra.sh  # Destroy shared VPC (only after all tenants removed)
./deprovision-all.sh           # Full teardown
```

## Directory Structure

```
ecp-eks-dx-infra/
├── bootstrap.sh                    # One-time account setup
├── build-control-plane-ami.sh      # Packer AMI build (~15-20 min)
├── provision-tenant.sh             # Provision tenant control plane
├── deprovision-tenant.sh           # Destroy tenant
├── provision-shared-infra.sh       # Provision shared VPC
├── deprovision-shared-infra.sh     # Destroy shared VPC
├── deprovision-all.sh              # Full teardown
├── tag-vpc-amis.sh                 # Tag AL2023 AMIs with EKS version metadata
├── terraform/                      # Tenant Terraform (IAM, SG, subnets, EC2, SQS)
├── terraform/vpc/                  # Shared VPC Terraform module
├── ami-builder/
│   ├── main.tf                     # Builder EC2 Terraform
│   └── scripts/
│       ├── install.sh              # AMI build entry point
│       ├── discover-eks-d.sh       # Discovers EKS-D component versions
│       ├── 00-configure-containerd.sh
│       ├── 01-install-base.sh
│       ├── 02-install-docker.sh
│       └── 04-install-helm.sh
├── eks-d-setup/                    # Boot-time cluster setup scripts
│   ├── workstation-boot.sh         # cloud-init entry point (idempotent)
│   ├── setup-eks-d.sh              # Boot-time cluster setup entry point
│   ├── 05-prepare-etcd.sh
│   ├── 06-install-aws-iam-authenticator.sh
│   ├── 07-install-eks-d.sh         # kubeadm init
│   ├── 08-install-cni.sh
│   ├── 09-install-cloud-provider.sh
│   ├── 10-configure-node.sh
│   ├── 13-install-ebs-csi.sh
│   ├── 15-install-karpenter.sh
│   ├── 14-install-metrics-server.sh
│   └── 16-install-cloudwatch.sh
└── node-pools/
    ├── configure-nodepools.sh      # Renders + applies Karpenter NodePool/EC2NodeClass
    └── chart/                      # Helm chart: NodePool + EC2NodeClass
```

## Cost Estimation

- **Control Plane**: ~$50-100/month per tenant (with Compute Savings Plan)
- **Worker Nodes**: Pay only when running, ~60-90% savings with Spot
- **Storage**: EBS volumes for etcd and container images
