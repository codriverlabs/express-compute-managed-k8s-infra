# Dependencies

## AWS Services

| Service | Purpose |
|---------|---------|
| EC2 | Workstation + worker node instances, AMI builder |
| IAM | Roles, instance profiles, policies |
| S3 | Terraform remote state (`eks-dx-tfstate-<account-id>`) |
| SSM Parameter Store | AMI IDs (`/eks-dx/ami/<arch>`), EKS-Optimized AMI discovery |
| STS | Account ID resolution |
| SQS | Karpenter spot interruption queue |
| CloudWatch | Metrics and logs |
| ELB | Load balancers via AWS CCM |
| Pricing API | Karpenter instance type selection |

## Kubernetes Components

| Component | Version | Source | Install Script |
|-----------|---------|--------|----------------|
| kubeadm | EKS-D 1.35.x | EKS-D release manifest | `06-install-eks-d.sh` |
| kubelet | EKS-D 1.35.x | EKS-D release manifest | `06-install-eks-d.sh` |
| kubectl | EKS-D 1.35.x | EKS-D release manifest | `06-install-eks-d.sh` |
| etcd | EKS-D | `public.ecr.aws/eks-distro/etcd-io` | kubeadm init |
| coredns | EKS-D | `public.ecr.aws/eks-distro/coredns` | kubeadm init |
| kube-apiserver | EKS-D | `public.ecr.aws/eks-distro/kubernetes` | kubeadm init |

## Helm Charts

| Chart | Version | Registry | Install Script |
|-------|---------|----------|----------------|
| karpenter | 1.10.0 | `oci://public.ecr.aws/karpenter/karpenter` | `11-install-karpenter.sh` |
| aws-cloud-controller-manager | latest | `https://kubernetes.github.io/cloud-provider-aws` | `08-install-cloud-provider.sh` |
| aws-ebs-csi-driver | latest | `https://kubernetes-sigs.github.io/aws-ebs-csi-driver` | `10-install-ebs-csi.sh` |
| amazon-cloudwatch-observability | latest | `https://aws-observability.github.io/helm-charts` | `13-install-cloudwatch.sh` |

## Kubernetes Manifests

| Manifest | Version | Source | Install Script |
|----------|---------|--------|----------------|
| aws-vpc-cni | v1.20.4 | `github.com/aws/amazon-vpc-cni-k8s` | `07-install-cni.sh` |

## Container Images (Pre-pulled in AMI)

| Image | Registry |
|-------|----------|
| EKS-D control plane (kube-apiserver, etcd, coredns) | `public.ecr.aws/eks-distro/` |
| aws-ebs-csi-driver | `public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver:v1.53.0` |
| Karpenter controller | `public.ecr.aws/karpenter/` |
| AWS CCM | `public.ecr.aws/` |
| CloudWatch agent | `public.ecr.aws/` |
| VPC CNI (aws-node) | `public.ecr.aws/` |
| ECR credential provider | `public.ecr.aws/eks-distro/kubernetes/` |
| aws-iam-authenticator | `public.ecr.aws/` |
| Metrics Server | `public.ecr.aws/` |

## Terraform Providers

| Provider | Module |
|----------|--------|
| `hashicorp/aws` | `terraform/`, `terraform/vpc/`, `ami-builder/` |

## System Packages (installed by scripts)

| Package | Script |
|---------|--------|
| containerd | `02-install-docker.sh` |
| docker | `02-install-docker.sh` |
| helm | `04-install-helm.sh` |
| aws-iam-authenticator binary | `05b-install-aws-iam-authenticator.sh` |
| ecr-credential-provider binary | `06-install-eks-d.sh` |

## External URLs

| URL | Purpose |
|-----|---------|
| `https://distro.eks.amazonaws.com/kubernetes-{ver}/kubernetes-{ver}-eks-{rel}.yaml` | EKS-D release manifest |
| `https://checkip.amazonaws.com/` | Auto-detect caller public IP for SSH CIDR |
| `http://169.254.169.254/` | EC2 instance metadata (IMDSv2) |
