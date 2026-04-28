# Workflows

## 1. First-Time Account Setup

```mermaid
sequenceDiagram
    actor Dev
    participant bootstrap.sh
    participant S3
    participant TF as terraform/vpc
    participant AWS

    Dev->>bootstrap.sh: ./bootstrap.sh us-east-1
    bootstrap.sh->>AWS: sts get-caller-identity
    bootstrap.sh->>S3: create eks-dx-tfstate-{account} (versioned, encrypted)
    bootstrap.sh->>TF: terraform init + apply
    TF->>AWS: Create shared VPC, IGW, NAT, route tables
    bootstrap.sh-->>Dev: "Next: ./deploy.sh"
```

## 2. Build Custom AMI

```mermaid
sequenceDiagram
    actor Dev
    participant build.sh
    participant TF as ami-builder/main.tf
    participant EC2 as Builder EC2
    participant install.sh
    participant SSM

    Dev->>build.sh: ./build.sh
    build.sh->>AWS: Create temp key pair
    build.sh->>TF: terraform apply
    TF->>EC2: Launch builder instance
    EC2->>install.sh: Run via SSH
    install.sh->>install.sh: Install base packages, EKS-D binaries
    install.sh->>install.sh: Pre-pull Helm charts (Karpenter, CCM, EBS CSI, CW)
    install.sh->>install.sh: Pre-pull all container images
    install.sh->>EC2: Copy eks-d-setup scripts to /opt/eks-d-setup/
    build.sh->>AWS: Create AMI from instance
    AWS->>SSM: Store AMI ID at /eks-dx/ami/{arch}
    build.sh->>TF: terraform destroy (builder instance)
    build.sh->>AWS: Delete temp key pair
```

## 3. Deploy Developer Workstation

```mermaid
sequenceDiagram
    actor Dev
    participant deploy.sh
    participant TF as terraform/
    participant EC2 as Workstation EC2
    participant boot as workstation-boot.sh

    Dev->>deploy.sh: ./deploy.sh
    deploy.sh->>AWS: Create EC2 key pair {workstation-name}
    deploy.sh->>deploy.sh: Write terraform/terraform.tfvars
    deploy.sh->>TF: terraform init (S3 backend)
    deploy.sh->>TF: terraform apply
    TF->>AWS: Create subnets, IAM role, SG, SQS queue
    TF->>EC2: Launch instance (AMI from SSM)
    EC2->>boot: user data runs workstation-boot.sh
    boot->>boot: 05-prepare-etcd.sh (format /dev/sdf)
    boot->>boot: 05b-install-aws-iam-authenticator.sh
    boot->>boot: 06-install-eks-d.sh (kubeadm init)
    boot->>boot: 07-install-cni.sh (disable ec2-net-utils, install VPC CNI)
    boot->>boot: 08-install-cloud-provider.sh
    boot->>boot: 09-configure-node.sh (untaint)
    boot->>boot: 10-install-ebs-csi.sh
    boot->>boot: 11-install-karpenter.sh
    boot->>boot: 13-install-cloudwatch.sh
    boot->>boot: Write /opt/eks-d/.installation_complete
    deploy.sh-->>Dev: Public IP + SSH command
```

## 4. Configure Karpenter NodePool

```mermaid
sequenceDiagram
    actor Dev
    participant configure-nodepools.sh
    participant SSM
    participant EC2 as AWS EC2 API
    participant K8s as Kubernetes API
    participant Helm

    Dev->>configure-nodepools.sh: ./configure-nodepools.sh alice
    configure-nodepools.sh->>K8s: kubectl version (get k8s minor)
    configure-nodepools.sh->>SSM: Get EKS-Optimized AL2023 AMI ID
    configure-nodepools.sh->>EC2: Describe subnets (tag: Developer=alice, SubnetType=Private)
    configure-nodepools.sh->>EC2: Describe security groups (name: eks-dx-workstation-alice)
    configure-nodepools.sh->>K8s: Get API server endpoint
    configure-nodepools.sh->>K8s: Get CA bundle + service CIDR
    configure-nodepools.sh->>Helm: helm template node-pools/chart/ (with discovered values)
    configure-nodepools.sh->>configure-nodepools.sh: Save to /opt/eks-d/karpenter_runtime_configuration/
    configure-nodepools.sh->>K8s: kubectl apply (NodePool + EC2NodeClass)
```

## 5. Worker Node Provisioning (Karpenter)

```mermaid
sequenceDiagram
    participant Pod as Pending Pod
    participant Karp as Karpenter
    participant EC2 as AWS EC2
    participant Worker as Worker Node
    participant Auth as aws-iam-authenticator

    Pod->>K8s: Pod scheduled (no available node)
    Karp->>EC2: RunInstances (AL2023 AMI, private subnet, instance profile)
    EC2->>Worker: Launch with nodeadm user data
    Worker->>Worker: nodeadm bootstrap (join cluster)
    Worker->>Auth: Authenticate via IAM role
    Auth->>K8s: Map to system:node:{hostname}
    Worker->>K8s: Register as node
    K8s->>Pod: Schedule pod on new node
```

## 6. Destroy Workstation

```mermaid
sequenceDiagram
    actor Dev
    participant destroy.sh
    participant TF as terraform/

    Dev->>destroy.sh: ./destroy.sh
    destroy.sh->>Dev: Prompt for username, region, arch
    destroy.sh->>Dev: "Type 'yes' to confirm"
    Dev->>destroy.sh: yes
    destroy.sh->>TF: terraform init (S3 backend)
    destroy.sh->>TF: terraform destroy
    TF->>AWS: Delete EC2, subnets, IAM role, SG, SQS queue
```

## Idempotency

- `workstation-boot.sh` checks for `/opt/eks-d/.installation_complete` and exits early if present — safe to reboot without re-running installation.
- `bootstrap.sh` checks for existing S3 bucket and VPC before creating them.
- `configure-nodepools.sh` saves rendered manifests to disk; re-apply without re-discovery: `kubectl apply -f /opt/eks-d/karpenter_runtime_configuration/karpenter-manifests.yaml`
