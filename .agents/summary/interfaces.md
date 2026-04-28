# Interfaces

## External AWS APIs Used

| Service | Usage |
|---------|-------|
| EC2 | Instance provisioning, subnet/SG discovery, AMI tagging |
| IAM | Role/instance profile creation, policy attachment |
| S3 | Terraform remote state storage |
| SSM Parameter Store | AMI ID storage (`/eks-dx/ami/<arch>`), EKS-Optimized AMI discovery |
| STS | Account ID resolution (`get-caller-identity`) |
| SQS | Karpenter interruption queue |
| CloudWatch | Metrics and logs via CloudWatch agent |
| ELB | Load balancer management via AWS CCM |
| Pricing API | Karpenter instance type pricing |

## Kubernetes API Endpoints

| Endpoint | Port | Consumer |
|----------|------|----------|
| kube-apiserver | 6443 | kubectl, worker nodes, Karpenter |
| kubelet API | 10250 | kubectl logs/exec, liveness probes |
| aws-iam-authenticator | 21362 | kube-apiserver (webhook auth) |

## Helm Chart Registries

| Chart | Source |
|-------|--------|
| Karpenter | `oci://public.ecr.aws/karpenter/karpenter` (OCI, not HTTP) |
| AWS Cloud Controller Manager | `https://kubernetes.github.io/cloud-provider-aws` |
| AWS EBS CSI Driver | `https://kubernetes-sigs.github.io/aws-ebs-csi-driver` |
| CloudWatch Observability | `https://aws-observability.github.io/helm-charts` |

## Container Image Registries

| Registry | Images |
|----------|--------|
| `public.ecr.aws/eks-distro/` | EKS-D control plane (kube-apiserver, etcd, coredns, kubelet) |
| `public.ecr.aws/ebs-csi-driver/` | EBS CSI driver |
| `public.ecr.aws/karpenter/` | Karpenter controller |
| `public.ecr.aws/eks-distro/kubernetes/` | ECR credential provider |

## Script Interfaces

### `deploy.sh` — Environment Variables
```
DEVELOPER_USERNAME   IAM username (required)
AWS_REGION           Target region (default: us-east-1)
ARCH                 x86_64 or arm64
DISK_SIZE_GB         Root disk size (default: 50)
SSH_CIDR             Allowed SSH CIDR (auto-detected from checkip.amazonaws.com)
TFSTATE_BUCKET       S3 state bucket (auto-derived: eks-dx-tfstate-<account-id>)
```

### `install-all.sh` / `workstation-boot.sh` — Arguments
```
$1  developer-signum  (required)
$2  cluster-name      (optional, default: <signum>-eks-dx)
```

### `configure-nodepools.sh` — Arguments
```
$1  developer-signum  (required)
$2  region            (optional, default: us-east-1)
$3  arch              (optional, default: arm64)
```

## Persistent State Files (on EC2)

| Path | Purpose |
|------|---------|
| `/opt/eks-d/cluster.env` | Cluster identity (`DEVELOPER_SIGNUM`, `CLUSTER_NAME`) — sourced by scripts |
| `/opt/eks-d/version.env` | EKS/EKS-D versions (`EKS_VERSION`, `EKSD_VERSION`) |
| `/opt/eks-d/manifests/` | Pre-downloaded EKS-D release manifest and VPC CNI manifest |
| `/opt/eks-d/charts/` | Pre-pulled Helm chart tarballs |
| `/opt/eks-d/.installation_complete` | Marker file — prevents re-run on reboot |
| `/opt/eks-d-setup/` | Copy of `eks-d-setup/` scripts (AMI path) |
| `/opt/eks-d/karpenter_runtime_configuration/karpenter-manifests.yaml` | Rendered NodePool + EC2NodeClass |
| `/etc/kubernetes/aws-iam-authenticator/` | Authenticator config + webhook kubeconfig |
| `/etc/kubernetes/credential-provider/config.yaml` | ECR credential provider config |

## Karpenter NodePool / EC2NodeClass Interface

The Helm chart (`node-pools/chart/`) accepts these values:

```yaml
clusterName: ""
developerSignum: ""
awsRegion: "us-east-1"
amiId: ""                    # EKS-Optimized AL2023 AMI ID
instanceProfile: ""          # eks-dx-workstation-<signum>
subnetId: ""                 # Private subnet ID
securityGroupId: ""          # Workstation security group ID
nodeConfig:
  apiServerEndpoint: ""      # https://<private-ip>:6443
  certificateAuthority: ""   # base64-encoded CA cert
  serviceCidr: "10.96.0.0/12"
nodePool:
  capacityType: "spot"
  arch: "arm64"
  instanceCategories: ["m", "c", "r"]
  instanceGenerationGt: "5"
  cpuLimit: "100"
  memoryLimit: "100Gi"
  consolidateAfter: "1m"
```
