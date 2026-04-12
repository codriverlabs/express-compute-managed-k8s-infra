# Data Models

## CloudFormation Templates

### Shared VPC Template
**File**: `infrastructure/shared-vpc-template.yaml`
- Creates VPC with CIDR 10.0.0.0/16
- Public subnet: 10.0.1.0/24
- Private subnet: 10.0.2.0/24
- NAT Gateway in public subnet
- Internet Gateway attached

### Developer Stack Template
**File**: `infrastructure/developer-stack-template.yaml`
- EC2 instance (t3.medium default)
- Security groups for control plane
- IAM instance profile
- User data for auto-setup
- EBS volumes for etcd

## Karpenter NodePool Spec

```yaml
# node-pools/spot-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "c"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
  limits:
    cpu: 100
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

## Environment Variables

| Variable | Description | Used By |
|----------|-------------|---------|
| CLUSTER_NAME | EKS-D cluster name | Karpenter, kubectl |
| AWS_REGION | AWS region | All AWS CLI calls |
| DEVELOPER_SIGNUM | Team member ID | NodePool configuration |

## Key Pair Configuration

- **Format**: PEM (for SSH)
- **Location**: ~/.ssh/
- **Permissions**: 0600
