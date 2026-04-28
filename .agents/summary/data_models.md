# Data Models

## Terraform Variables — Workstation (`terraform/variables.tf`)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `developer_username` | string | — | IAM username; used in resource names and tags |
| `workstation_name` | string | — | EC2 name; derived as `<sanitised-username>-eks-dx-<arch>` |
| `aws_region` | string | — | Deployment region |
| `arch` | string | `x86_64` | `x86_64` or `arm64` |
| `instance_type` | string | `t3.large` | EC2 instance type (overridden by `deploy.sh`) |
| `key_pair_name` | string | `""` | SSH key pair name |
| `disk_size_gb` | number | `50` | Root EBS volume size |
| `allowed_cidr_blocks` | list(string) | `[]` | SSH ingress CIDRs |
| `vpc_id` | string | `""` | VPC ID (auto-discovered by tag if empty) |
| `subnet_index` | number | `null` | Subnet /24 index (auto-calculated if null, range 0-50) |
| `project_name` | string | `eks-d` | Resource naming prefix |

## Terraform Outputs — Workstation

| Output | Description |
|--------|-------------|
| `workstation_public_ip` | Public IP of the EC2 instance |
| `workstation_name` | Resolved workstation name |
| `key_file` | Path to the generated SSH private key |

## Cluster Identity (`/opt/eks-d/cluster.env`)

```bash
DEVELOPER_SIGNUM="alice"
CLUSTER_NAME="alice-eks-dx"
```

## Version Config (`/opt/eks-d/version.env`)

```bash
EKS_VERSION="1.35"
EKSD_VERSION="1.35.8"
TAGGED_AMIS="eks-dx-1.35"
```

## Karpenter NodePool (rendered by `configure-nodepools.sh`)

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["m", "c", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
  limits:
    cpu: "100"
    memory: "100Gi"
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: "1m"
```

## EC2NodeClass (rendered by `configure-nodepools.sh`)

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  instanceProfile: "eks-dx-workstation-<signum>"
  amiFamily: Custom          # Not AL2023 — avoids Karpenter v1.10 ResolveClusterCIDR bug
  amiSelectorTerms:
    - id: "<ami-id>"         # EKS-Optimized AL2023 AMI
  subnetSelectorTerms:
    - id: "<subnet-id>"      # Private subnet
  securityGroupSelectorTerms:
    - id: "<sg-id>"
  userData: |                # nodeadm MIME multipart for AL2023
    # NodeConfig with cluster name, API endpoint, CA bundle, service CIDR
  metadataOptions:
    httpTokens: required     # IMDSv2
    httpPutResponseHopLimit: 2
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
```

## IAM Role Policy Structure

```mermaid
classDiagram
    class WorkstationRole {
        name: eks-dx-workstation-{username}
        trust: ec2.amazonaws.com
    }
    class ManagedPolicies {
        AmazonSSMManagedInstanceCore
        AmazonEC2ContainerRegistryPullOnly
        AmazonEKS_CNI_Policy
        AmazonEBSCSIDriverEKSClusterScopedPolicy
        CloudWatchAgentServerPolicy
    }
    class InlineKarpenter {
        name: eks-dx-karpenter
        ec2: Describe* (unrestricted)
        ec2: RunInstances/CreateFleet (tag-scoped)
        ec2: TerminateInstances (tag-scoped)
        sqs: Receive/Delete (cluster queue)
        iam: PassRole (self)
    }
    class InlineCloudProvider {
        name: eks-dx-cloud-provider
        ec2: Describe* (unrestricted)
        ec2: CreateVolume/Route/SG (tag-scoped)
        ec2: Modify/Attach/Delete (tag-scoped)
        elb: Create/Delete/Modify (tag-scoped)
    }
    WorkstationRole --> ManagedPolicies
    WorkstationRole --> InlineKarpenter
    WorkstationRole --> InlineCloudProvider
```

## Security Group Rules

| Direction | Port | Protocol | Source |
|-----------|------|----------|--------|
| Ingress | 22 | TCP | `allowed_cidr_blocks` (caller IP) |
| Ingress | 6443 | TCP | VPC CIDR (worker nodes + kubectl) |
| Ingress | 10250 | TCP | VPC CIDR (kubelet API) |
| Ingress | all | all | Self (pod networking between nodes) |
| Egress | all | all | 0.0.0.0/0 |
