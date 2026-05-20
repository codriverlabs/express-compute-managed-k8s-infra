# AGENTS.md - AI Assistant Guide

## Project Overview
**EKS-D-Xpress (EKS-DX)** — Self-managed Kubernetes (EKS-D 1.35) control planes on EC2, part of the Express Compute (ECP) product suite. Each tenant gets an isolated single-node control plane EC2 instance; Karpenter v1.10.0 provisions Spot workers on demand.

## Directory Overview

```
ecp-eks-dx-infra/
├── bootstrap.sh                    # One-time: create S3 state bucket + shared VPC
├── build-control-plane-ami.sh      # Build custom AMI (~15-20 min, pre-pulls all images)
├── provision-tenant.sh             # Provision tenant control plane via Terraform
├── deprovision-tenant.sh           # Destroy tenant control plane
├── provision-shared-infra.sh       # Deploy shared VPC (tags AL2023 AMIs, runs Terraform)
├── deprovision-shared-infra.sh     # Destroy shared VPC
├── deprovision-all.sh              # Full teardown
├── tag-vpc-amis.sh                 # Tag AL2023 AMIs with EKS version metadata
├── terraform/
│   ├── main.tf               # Tenant EC2, IAM role, SG, subnets, SQS queue
│   ├── variables.tf
│   └── vpc/                  # Shared VPC Terraform module
├── ami-builder/
│   ├── main.tf               # Builder EC2 Terraform
│   └── scripts/
│       ├── install.sh        # AMI build entry point (pre-pulls images/charts/binaries)
│       ├── discover-eks-d.sh # Discovers EKS-D component versions from release manifest
│       ├── 00-configure-containerd.sh  # Build-time: containerd config
│       ├── 01-install-base.sh          # Build-time: base packages
│       ├── 02-install-docker.sh        # Build-time: containerd install
│       └── 04-install-helm.sh          # Build-time: helm install
├── eks-d-setup/                    # Boot-time cluster setup scripts
│   ├── workstation-boot.sh   # EC2 first-boot entry point (idempotent, calls setup-eks-d.sh)
│   ├── setup-eks-d.sh        # Boot-time cluster setup entry point
│   ├── 05-prepare-etcd.sh
│   ├── 05b-install-aws-iam-authenticator.sh  # Must run before 06
│   ├── 06-install-eks-d.sh   # kubeadm init
│   ├── 07-install-cni.sh
│   ├── 08-install-cloud-provider.sh
│   ├── 09-configure-node.sh
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
| Build control plane AMI | `./build-control-plane-ami.sh` |
| Provision shared VPC | `./provision-shared-infra.sh [region]` |
| Provision tenant | `./provision-tenant.sh` |
| Deprovision tenant | `./deprovision-tenant.sh` |
| Configure NodePool | `./node-pools/configure-nodepools.sh <tenant-id> [region]` (on EC2) |

## Deployment Sequence

```
bootstrap.sh                    # once per account
  └── provision-shared-infra.sh # once per region
build-control-plane-ami.sh      # once per k8s version / arch
provision-tenant.sh             # per tenant
  └── EC2 boots automatically
      └── workstation-boot.sh
          └── setup-eks-d.sh    # cluster ready in ~3 min
node-pools/configure-nodepools.sh  # on EC2, after cluster is ready
```

## Repo-Specific Patterns

### Naming Conventions
- Workstation name: `<sanitised-username>-eks-dx-<arch>` (e.g., `alice-eks-dx-arm64`)
- Cluster name: `<signum>-eks-dx`
- IAM role + instance profile: `<username>-eks-dx-<arch>` (shared by control plane and worker nodes)
- SQS queue: same as cluster name (Karpenter interruption)
- Terraform state bucket: `eks-dx-tfstate-<account-id>-<region>` (auto-derived, no config needed)
- Terraform state key: `eks-dx/<workstation-name>/terraform.tfstate`
- SSM AMI parameter: `/eks-dx/ami/<region>/<kubernetes-version>/x86_64` and `/eks-dx/ami/<region>/<kubernetes-version>/arm64` (e.g. `/eks-dx/ami/us-east-1/1.35/x86_64`)

### Cluster Identity Persistence
Scripts source `/opt/eks-d/cluster.env` for `TENANT_ID` and `CLUSTER_NAME` rather than requiring arguments every time. Written by `setup-eks-d.sh` / `workstation-boot.sh`.

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
Control plane and worker nodes share the same IAM role (`<username>-eks-dx-<arch>`). `aws-iam-authenticator` (static pod) maps that role to `system:node:{{EC2PrivateDNSName}}` in `system:nodes` — no separate worker node role or `aws-auth` ConfigMap needed.

### NodePool Configuration
Do **not** apply `spot-nodepool.yaml` or `ondemand-nodepool.yaml` directly — they use the deprecated `v1beta1` API. Always use `configure-nodepools.sh` which discovers runtime values (AMI ID, subnet, SG, CA bundle) and renders the Helm chart in `node-pools/chart/`.

### AMI Pre-pull Strategy
`ami-builder/scripts/install.sh` pre-pulls all container images and Helm chart tarballs into the AMI at `/opt/eks-d/charts/` and `/opt/eks-d/manifests/`. Setup scripts prefer these cached artifacts over downloading at boot time.

### Environment Variables for `provision-tenant.sh`
Set these to skip interactive prompts:
```
TENANT_ID, AWS_REGION, ARCH, DISK_SIZE_GB, SSH_CIDR, TFSTATE_BUCKET, KUBERNETES_VERSION, WORKSTATION_MODE
```

## Custom Instructions
<!-- This section is for human and agent-maintained operational knowledge.
     Add repo-specific conventions, gotchas, and workflow rules here.
     This section is preserved exactly as-is when re-running codebase-summary. -->
