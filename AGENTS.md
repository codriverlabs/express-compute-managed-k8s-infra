# AGENTS.md - AI Assistant Guide

## Project Overview
EKS-DX — Self-managed Kubernetes (EKS-D 1.35) developer workstations on EC2 with Karpenter v1.10.0 managing worker nodes. Each developer gets an isolated single-node control plane EC2 instance; Karpenter provisions Spot/On-Demand workers on demand.

## Directory Overview

```
ecp-single-node-eks-d/
├── bootstrap.sh              # One-time: create S3 state bucket + shared VPC
├── build.sh                  # Build custom AMI (~20-30 min, pre-pulls all images)
├── deploy.sh                 # Deploy developer workstation via Terraform
├── destroy.sh                # Destroy developer workstation
├── deploy-vpc.sh             # Deploy shared VPC (tags AL2023 AMIs, runs Terraform)
├── tag-vpc-amis.sh           # Tag AL2023 AMIs with EKS version metadata
├── terraform/
│   ├── main.tf               # Workstation EC2, IAM role, SG, subnets, SQS queue
│   ├── variables.tf
│   └── vpc/                  # Shared VPC Terraform module
├── ami-builder/
│   ├── main.tf               # Builder EC2 Terraform
│   └── scripts/
│       ├── install.sh        # Pre-pulls all images/charts/binaries into AMI
│       └── discover-eks-d.sh # Discovers EKS-D component versions from release manifest
├── eks-d-setup/
│   ├── workstation-boot.sh   # EC2 first-boot entry point (AMI path, idempotent)
│   ├── install-all.sh        # Manual full install entry point (non-AMI path)
│   ├── 00–09-*.sh            # Ordered setup scripts (containerd → kubeadm init → CNI → CCM)
│   ├── 05b-install-aws-iam-authenticator.sh  # Must run before 06
│   ├── 10-install-ebs-csi.sh
│   ├── 11-install-karpenter.sh
│   ├── 12-install-metrics-server.sh
│   └── 13-install-cloudwatch.sh
└── node-pools/
    ├── configure-nodepools.sh  # Discovers runtime values, renders + applies Helm chart
    └── chart/                  # Helm chart: NodePool + EC2NodeClass (karpenter.sh/v1)
```

## Key Entry Points

| Task | Command |
|------|---------|
| First-time account setup | `./bootstrap.sh [region]` |
| Build AMI | `./build.sh` |
| Deploy workstation | `./deploy.sh` |
| Destroy workstation | `./destroy.sh` |
| Deploy shared VPC | `./deploy-vpc.sh [region]` |
| Install EKS-D (non-AMI) | `./eks-d-setup/install-all.sh <signum>` (on EC2) |
| Configure NodePool | `./node-pools/configure-nodepools.sh <signum> [region]` (on EC2) |

## Deployment Paths

**AMI path (recommended):** `build.sh` → `deploy.sh` → EC2 boots → `workstation-boot.sh` runs automatically → cluster ready in ~5 min.

**Fresh install path:** `deploy.sh` → SSH to EC2 → `eks-d-setup/install-all.sh <signum>` → ~30 min.

## Repo-Specific Patterns

### Naming Conventions
- Workstation name: `<sanitised-username>-eks-dx-<arch>` (e.g., `alice-eks-dx-arm64`)
- Cluster name: `<signum>-eks-dx`
- IAM role + instance profile: `eks-dx-workstation-<username>` (shared by control plane and worker nodes)
- SQS queue: same as cluster name (Karpenter interruption)
- Terraform state bucket: `eks-dx-tfstate-<account-id>` (auto-derived, no config needed)
- Terraform state key: `eks-dx/<workstation-name>/terraform.tfstate`
- SSM AMI parameter: `/eks-dx/ami/x86_64` and `/eks-dx/ami/arm64`

### Cluster Identity Persistence
Scripts source `/opt/eks-d/cluster.env` for `DEVELOPER_SIGNUM` and `CLUSTER_NAME` rather than requiring arguments every time. Written by `install-all.sh` / `workstation-boot.sh`.

### Idempotent Boot
`workstation-boot.sh` checks `/opt/eks-d/.installation_complete` and exits early if present — rebooting the EC2 does not re-run installation.

### Karpenter on EKS-D (non-EKS)
- `settings.eksControlPlane=false` — no EKS DescribeCluster calls
- `settings.clusterEndpoint` set explicitly to `https://<private-ip>:6443`
- `amiFamily: Custom` (not `AL2023`) — avoids Karpenter v1.10 bug where `ResolveClusterCIDR` always runs for AL2023 regardless of `eksControlPlane=false`
- Helm chart pulled from OCI: `oci://public.ecr.aws/karpenter/karpenter` — `helm repo add` does not work; run `helm registry logout public.ecr.aws` first
- Use `karpenter.sh/v1` and `karpenter.k8s.aws/v1` APIs (not v1beta1)

### Script Ordering Constraint
`05b-install-aws-iam-authenticator.sh` **must** run before `06-install-eks-d.sh`. The API server is configured at `kubeadm init` time to use the authenticator webhook; if the webhook config file is absent, the API server crashes and `kubeadm init` never completes.

### ec2-net-utils Must Be Disabled
`07-install-cni.sh` disables `ec2-net-utils` policy-routes before installing AWS VPC CNI. On AL2023, `ec2-net-utils` adds secondary ENI IPs to the local routing table and creates per-ENI ip rules that conflict with VPC CNI pod routing (symptom: CoreDNS timeouts, cross-node pod connectivity failures).

### Worker Node Authentication
Control plane and worker nodes share the same IAM role (`eks-dx-workstation-<username>`). `aws-iam-authenticator` (static pod) maps that role to `system:node:{{EC2PrivateDNSName}}` in `system:nodes` — no separate worker node role or `aws-auth` ConfigMap needed.

### NodePool Configuration
Do **not** apply `spot-nodepool.yaml` or `ondemand-nodepool.yaml` directly — they use the deprecated `v1beta1` API. Always use `configure-nodepools.sh` which discovers runtime values (AMI ID, subnet, SG, CA bundle) and renders the Helm chart in `node-pools/chart/`.

### AMI Pre-pull Strategy
`ami-builder/scripts/install.sh` pre-pulls all container images and Helm chart tarballs into the AMI at `/opt/eks-d/charts/` and `/opt/eks-d/manifests/`. Setup scripts prefer these cached artifacts over downloading at boot time.

### Environment Variables for `deploy.sh`
Set these to skip interactive prompts:
```
DEVELOPER_USERNAME, AWS_REGION, ARCH, DISK_SIZE_GB, SSH_CIDR, TFSTATE_BUCKET
```

## Custom Instructions
<!-- This section is for human and agent-maintained operational knowledge.
     Add repo-specific conventions, gotchas, and workflow rules here.
     This section is preserved exactly as-is when re-running codebase-summary. -->
