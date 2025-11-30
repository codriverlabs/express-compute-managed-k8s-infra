# Multi-Tenant Security & Isolation

## Overview

This architecture implements defense-in-depth security for multi-tenant EKS-D deployments in a shared VPC.

## Isolation Layers

### 1. Network Isolation

**Dedicated Subnets Per Developer:**
- Each developer has a unique public subnet (10.0.{index}.0/24)
- Each developer has a unique private subnet (10.0.{100+index}.0/24)
- Worker nodes can only be launched in developer's private subnet

**Security Groups:**
- Separate security groups per developer
- Tagged with `Developer` name
- No cross-developer traffic by default

### 2. IAM Policy Restrictions

#### Karpenter Controller Restrictions

**Subnet Restriction:**
```
Karpenter can ONLY launch instances in developer's private subnet
Resource: arn:aws:ec2:region:account:subnet/${DeveloperPrivateSubnet}
```

**Tag Enforcement:**
```
All created resources MUST have:
- Developer: {developer-name}
- karpenter.sh/cluster: {cluster-name}
```

**Security Group Restriction:**
```
Can ONLY use developer's worker node security group
Resource: arn:aws:ec2:region:account:security-group/${DeveloperSecurityGroup}
```

**Termination Restriction:**
```
Can ONLY terminate instances with:
- ec2:ResourceTag/Developer: {developer-name}
- ec2:ResourceTag/karpenter.sh/cluster: {cluster-name}
```

#### Shared VPC Protection

**Explicit Deny Policies:**
- Cannot modify other developers' resources
- Cannot delete/modify shared VPC infrastructure:
  - VPC
  - NAT Gateway
  - Internet Gateway
  - Shared route tables
  - Shared subnets

### 3. Resource Tagging

**All resources tagged with:**
- `Developer`: Developer name (enforced)
- `ManagedBy`: CloudFormation
- `karpenter.sh/cluster`: Cluster name (for Karpenter discovery)

**Tag Enforcement:**
- IAM policies require tags on resource creation
- Cannot create resources without proper tags
- Cannot modify resources with different Developer tag

### 4. Audit & Monitoring

**VPC Flow Logs:**
- Enabled at VPC level
- Enabled per developer subnet
- Logs stored in CloudWatch Logs
- Retention: 7 days (configurable)

**CloudTrail Integration:**
- All API calls logged
- Filter by Developer tag
- Track resource creation/deletion

**Cost Tracking:**
- All resources tagged for cost allocation
- Filter by Developer in Cost Explorer
- Track per-developer spending

## Security Best Practices

### For Administrators

1. **Subnet Index Management:**
   - Maintain a registry of assigned subnet indices
   - Never reuse indices while stacks exist
   - Document which developer has which index

2. **Regular Audits:**
   ```bash
   # Check VPC Flow Logs
   aws logs tail /aws/vpc/eks-d-flow-logs --follow
   
   # Check resources by developer
   aws ec2 describe-instances \
     --filters "Name=tag:Developer,Values=alice" \
     --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags]'
   ```

3. **Cost Monitoring:**
   ```bash
   # View costs by developer
   aws ce get-cost-and-usage \
     --time-period Start=2025-01-01,End=2025-01-31 \
     --granularity MONTHLY \
     --metrics BlendedCost \
     --group-by Type=TAG,Key=Developer
   ```

### For Developers

1. **Verify Isolation:**
   ```bash
   # Check your resources
   aws ec2 describe-instances \
     --filters "Name=tag:Developer,Values=YOUR_NAME"
   
   # Verify subnet assignment
   aws ec2 describe-subnets \
     --filters "Name=tag:Developer,Values=YOUR_NAME"
   ```

2. **Karpenter NodePool Configuration:**
   ```yaml
   apiVersion: karpenter.sh/v1beta1
   kind: NodePool
   metadata:
     name: default
   spec:
     template:
       spec:
         requirements:
           - key: karpenter.sh/capacity-type
             operator: In
             values: ["spot"]
         nodeClassRef:
           name: default
   ---
   apiVersion: karpenter.k8s.aws/v1beta1
   kind: EC2NodeClass
   metadata:
     name: default
   spec:
     amiFamily: AL2023
     role: YOUR_DEVELOPER_NAME-eks-d-worker-node-role
     subnetSelectorTerms:
       - tags:
           Developer: YOUR_DEVELOPER_NAME
     securityGroupSelectorTerms:
       - tags:
           Developer: YOUR_DEVELOPER_NAME
     tags:
       Developer: YOUR_DEVELOPER_NAME
       karpenter.sh/cluster: YOUR_CLUSTER_NAME
   ```

## Threat Model & Mitigations

### Threat: Developer A terminates Developer B's instances

**Mitigation:**
- IAM policy explicitly denies termination of instances without matching Developer tag
- Condition: `ec2:ResourceTag/Developer: {developer-name}`

### Threat: Developer launches instances in wrong subnet

**Mitigation:**
- IAM policy restricts RunInstances to specific subnet ARN
- Resource: `arn:aws:ec2:region:account:subnet/${DeveloperPrivateSubnet}`

### Threat: Developer modifies shared VPC infrastructure

**Mitigation:**
- Explicit Deny policy on shared VPC resources
- Prevents deletion/modification of NAT Gateway, IGW, route tables

### Threat: Developer creates untagged resources

**Mitigation:**
- IAM policy requires tags on resource creation
- Condition: `aws:RequestTag/Developer: {developer-name}`

### Threat: Cost attribution unclear

**Mitigation:**
- All resources tagged with Developer name
- VPC Flow Logs per subnet
- CloudWatch metrics per developer

## Compliance & Governance

### Resource Naming Convention

```
{developer-name}-{resource-type}-{purpose}

Examples:
- alice-eks-d-control-plane
- alice-worker-nodes-sg
- alice-public-subnet
```

### Tag Requirements

**Mandatory Tags:**
- `Developer`: Developer name
- `ManagedBy`: CloudFormation
- `karpenter.sh/cluster`: Cluster name (for Karpenter resources)

**Optional Tags:**
- `Environment`: dev/staging/prod
- `CostCenter`: For chargeback
- `Project`: Project name

### Access Control

**Control Plane Access:**
- SSH via Elastic IP (developer-specific)
- Session Manager (via IAM)
- Kubernetes API (via kubeconfig)

**Worker Node Access:**
- No direct SSH (managed by Karpenter)
- Session Manager for debugging
- Logs via CloudWatch

## Incident Response

### Unauthorized Resource Creation

```bash
# Find resources without proper tags
aws ec2 describe-instances \
  --filters "Name=tag-key,Values=Developer" \
  --query 'Reservations[].Instances[?!Tags[?Key==`Developer`]]'

# Terminate unauthorized instances
aws ec2 terminate-instances --instance-ids i-xxxxx
```

### Subnet Exhaustion

```bash
# Check subnet utilization
aws ec2 describe-subnets \
  --subnet-ids subnet-xxxxx \
  --query 'Subnets[].AvailableIpAddressCount'

# If needed, expand to larger CIDR or add second subnet
```

### Cost Overrun

```bash
# Check running instances by developer
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=alice" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]'

# Stop instances if needed
aws ec2 stop-instances --instance-ids i-xxxxx
```

## Validation

### Test Isolation

```bash
# As Developer A, try to terminate Developer B's instance (should fail)
aws ec2 terminate-instances --instance-ids i-developer-b-instance

# Expected: AccessDenied error

# Try to launch instance in Developer B's subnet (should fail)
aws ec2 run-instances \
  --subnet-id subnet-developer-b \
  --image-id ami-xxxxx

# Expected: AccessDenied error
```

### Verify Tags

```bash
# Check all resources have proper tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Developer,Values=alice \
  --resource-type-filters ec2:instance ec2:subnet ec2:security-group
```
