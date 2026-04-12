# Interfaces

## Deployment Interfaces

### 1. VPC Deployment
**Script**: `infrastructure/deploy-vpc.sh`
```bash
./deploy-vpc.sh <region>
```
- Creates shared VPC with public/private subnets
- Outputs: VPC ID, Subnet IDs, Security Groups

### 2. Developer Stack Deployment
**Script**: `infrastructure/deploy-developer.sh`
```bash
./deploy-developer.sh <developer-signum> <instance-number> <key-pair-name> <auto-setup>
```
- Parameters:
  - `developer-signum`: Team member identifier (e.g., "alice")
  - `instance-number`: Instance count
  - `key-pair-name`: SSH key pair
  - `auto-setup`: "true" for automated user data, "false" for manual

### 3. EKS-D Installation
**Script**: `eks-d-setup/install.sh` or `eks-d-setup/install-all.sh`
- Runs on EC2 after SSH access
- Installs all EKS-D components in sequence

### 4. Karpenter Installation
**Script**: `karpenter-config/install-karpenter.sh`
- Requires: CLUSTER_NAME, AWS_REGION environment variables

### 5. NodePool Configuration
**Script**: `node-pools/configure-nodepools.sh`
```bash
./configure-nodepools.sh <developer-signum> [region]
```

## CloudFormation Outputs

| Output Key | Description |
|------------|-------------|
| ClusterName | EKS-D cluster name |
| PrivateSubnetId | Private subnet for nodes |
| WorkerSecurityGroupId | Security group for workers |
| WorkerNodeInstanceProfile | IAM instance profile |
| ControlPlanePublicIP | SSH access IP |

## Kubernetes Interfaces

### NodePool API
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
```

### EC2NodeClass API
```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: <instance-role>
  subnetSelectorTerms:
    - id: <subnet-id>
  securityGroupSelectorTerms:
    - id: <sg-id>
```
