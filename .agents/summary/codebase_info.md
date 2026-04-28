# Codebase Info

## Project
**EKS-DX** — Self-managed Kubernetes (EKS-D) developer workstations on EC2 with Karpenter-managed worker nodes.

## Language / Technology Stack
- **Shell (Bash)** — all lifecycle scripts, installation scripts
- **HCL (Terraform)** — infrastructure provisioning (workstation EC2, shared VPC, AMI builder)
- **YAML** — Kubernetes manifests, Helm chart templates, Karpenter NodePool/EC2NodeClass

## Versions
| Component | Version |
|-----------|---------|
| Kubernetes (EKS-D) | 1.35 |
| Karpenter | 1.10.0 |
| AWS VPC CNI | v1.20.4 |
| EBS CSI Driver | v1.53.0 |

## Directory Structure

```
ecp-single-node-eks-d/
├── bootstrap.sh              # One-time account setup (S3 state bucket + VPC)
├── build.sh                  # Build custom AMI (~20-30 min)
├── deploy.sh                 # Deploy developer workstation via Terraform
├── destroy.sh                # Destroy developer workstation
├── deploy-vpc.sh             # Deploy shared VPC
├── tag-vpc-amis.sh           # Tag AL2023 AMIs with EKS version
├── terraform/
│   ├── main.tf               # Workstation EC2, IAM, SG, subnets, SQS
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf            # S3 remote state
│   └── vpc/                  # Shared VPC Terraform module
├── ami-builder/
│   ├── main.tf               # Builder EC2 Terraform
│   ├── scripts/
│   │   ├── install.sh        # Pre-pulls all images/charts/binaries into AMI
│   │   ├── discover-eks-d.sh # Discovers EKS-D component versions
│   │   └── build-with-version.sh
│   └── cleanup-amis.sh
├── eks-d-setup/
│   ├── install-all.sh        # Full fresh install (non-AMI path)
│   ├── workstation-boot.sh   # Boot-time setup (AMI path, idempotent)
│   ├── 00-configure-containerd.sh
│   ├── 01-install-base.sh
│   ├── 02-install-docker.sh
│   ├── 03-install-kubectl.sh
│   ├── 04-install-helm.sh
│   ├── 05-prepare-etcd.sh
│   ├── 05b-install-aws-iam-authenticator.sh  # MUST precede 06
│   ├── 06-install-eks-d.sh   # kubeadm init with EKS-D images
│   ├── 07-install-cni.sh     # AWS VPC CNI (disables ec2-net-utils first)
│   ├── 08-install-cloud-provider.sh
│   ├── 09-configure-node.sh
│   ├── 10-install-ebs-csi.sh
│   ├── 11-install-karpenter.sh
│   ├── 12-install-metrics-server.sh
│   └── 13-install-cloudwatch.sh
└── node-pools/
    ├── configure-nodepools.sh  # Discovers runtime values, renders + applies chart
    ├── chart/                  # Helm chart: NodePool + EC2NodeClass
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── nodepool.yaml
    │       └── ec2nodeclass.yaml
    ├── spot-nodepool.yaml      # Legacy static template (v1beta1, do not use)
    └── ondemand-nodepool.yaml  # Legacy static template (v1beta1, do not use)
```

## Naming Conventions
- Workstation name: `<sanitised-username>-eks-dx-<arch>` (e.g., `alice-eks-dx-arm64`)
- Cluster name: `<developer-signum>-eks-dx` (default)
- IAM role / instance profile: `eks-dx-workstation-<developer-username>`
- SQS queue: same as cluster name (Karpenter interruption)
- Terraform state key: `eks-dx/<workstation-name>/terraform.tfstate`
- Terraform state bucket: `eks-dx-tfstate-<account-id>` (auto-derived)
- SSM AMI parameter: `/eks-dx/ami/x86_64` and `/eks-dx/ami/arm64`
