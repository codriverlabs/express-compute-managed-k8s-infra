# Multi-Tenant EKS-D Deployment Guide

## Architecture Overview

This setup uses a **shared VPC** with **dedicated subnets per developer** for optimal cost, isolation, and auditing.

### Cost Savings
- **One NAT Gateway** (~$32/month) shared by all developers
- **Free Elastic IPs** (when attached to running instances)
- **Free subnets** (no per-subnet charges)

### Tenant Isolation
- Each developer gets dedicated public subnet (10.0.{index}.0/24)
- Each developer gets dedicated private subnet (10.0.{100+index}.0/24)
- Separate security groups per developer
- Network-level isolation

### Auditing
- VPC Flow Logs per subnet for traffic analysis
- CloudTrail events tagged by developer
- All resources tagged with Developer name
- Easy to track costs and usage per developer

## Deployment Steps

### Step 1: Deploy Shared VPC (Once)

```bash
cd infrastructure

# Deploy shared VPC infrastructure
aws cloudformation create-stack \
  --stack-name eks-d-shared-vpc \
  --template-body file://shared-vpc-template.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=eks-d \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name eks-d-shared-vpc \
  --region us-east-1

# View outputs
aws cloudformation describe-stacks \
  --stack-name eks-d-shared-vpc \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Step 2: Deploy Per-Developer Stack

Each developer needs a unique subnet index (1-50).

**Using the deployment script (recommended):**

```bash
# For manual testing (no user data)
./deploy-developer.sh alice 1 my-key-pair false

# For automated deployment (with user data)
./deploy-developer.sh bob 2 my-key-pair true
```

**Script parameters:**
- `developer-signum`: Developer name (lowercase, hyphens only)
- `subnet-index`: Unique number 1-50
- `key-pair-name`: Your EC2 key pair name
- `enable-userdata`: `true` for automated setup, `false` for manual testing

**Manual CloudFormation (alternative):**

**Developer 1 (alice):**
```bash
aws cloudformation create-stack \
  --stack-name eks-d-alice \
  --template-body file://developer-stack-template.yaml \
  --parameters \
    ParameterKey=SharedVpcStackName,ParameterValue=eks-d-shared-vpc \
    ParameterKey=DeveloperName,ParameterValue=alice \
    ParameterKey=SubnetIndex,ParameterValue=1 \
    ParameterKey=KeyPairName,ParameterValue=my-key-pair \
    ParameterKey=ControlPlaneInstanceType,ParameterValue=t4a.large \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**Developer 2 (bob):**
```bash
aws cloudformation create-stack \
  --stack-name eks-d-bob \
  --template-body file://developer-stack-template.yaml \
  --parameters \
    ParameterKey=SharedVpcStackName,ParameterValue=eks-d-shared-vpc \
    ParameterKey=DeveloperName,ParameterValue=bob \
    ParameterKey=SubnetIndex,ParameterValue=2 \
    ParameterKey=KeyPairName,ParameterValue=my-key-pair \
    ParameterKey=ControlPlaneInstanceType,ParameterValue=t4a.large \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Step 3: Get Connection Info

```bash
# Get SSH command and Kubernetes endpoint
aws cloudformation describe-stacks \
  --stack-name eks-d-alice \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Subnet Allocation

| Developer | Index | Public Subnet    | Private Subnet    |
|-----------|-------|------------------|-------------------|
| alice     | 1     | 10.0.1.0/24      | 10.0.101.0/24     |
| bob       | 2     | 10.0.2.0/24      | 10.0.102.0/24     |
| charlie   | 3     | 10.0.3.0/24      | 10.0.103.0/24     |
| ...       | ...   | ...              | ...               |

**Reserved:**
- 10.0.0.0/24 - NAT Gateway subnet
- 10.0.1-99.0/24 - Public subnets (99 developers max)
- 10.0.100-199.0/24 - Private subnets (99 developers max)

## Auditing & Monitoring

### View VPC Flow Logs
```bash
# All traffic in shared VPC
aws logs tail /aws/vpc/eks-d-flow-logs --follow

# Filter by developer's subnet
aws logs filter-log-events \
  --log-group-name /aws/vpc/eks-d-flow-logs \
  --filter-pattern "10.0.1.0"
```

### Cost Tracking
All resources are tagged with:
- `Developer`: Developer name
- `ManagedBy`: CloudFormation
- `Project`: eks-d

Use AWS Cost Explorer to filter by these tags.

### CloudTrail Events
```bash
# View API calls by developer
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=alice-eks-d-control-plane \
  --max-results 50
```

## Updating Stacks

### Update Developer Stack
```bash
aws cloudformation update-stack \
  --stack-name eks-d-alice \
  --template-body file://developer-stack-template.yaml \
  --parameters \
    ParameterKey=SharedVpcStackName,ParameterValue=eks-d-shared-vpc \
    ParameterKey=DeveloperName,ParameterValue=alice \
    ParameterKey=SubnetIndex,ParameterValue=1 \
    ParameterKey=KeyPairName,ParameterValue=my-key-pair \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Deleting Stacks

**Important:** Delete developer stacks before deleting shared VPC.

```bash
# Delete developer stack
aws cloudformation delete-stack \
  --stack-name eks-d-alice \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name eks-d-alice \
  --region us-east-1

# After all developer stacks are deleted, delete shared VPC
aws cloudformation delete-stack \
  --stack-name eks-d-shared-vpc \
  --region us-east-1
```

## Validation

### Validate Templates
```bash
# Validate shared VPC template
aws cloudformation validate-template \
  --template-body file://shared-vpc-template.yaml

# Validate developer template
aws cloudformation validate-template \
  --template-body file://developer-stack-template.yaml
```

## Troubleshooting

### Check Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name eks-d-alice \
  --query 'Stacks[0].StackStatus'
```

### View Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name eks-d-alice \
  --max-items 20
```

### Check VPC Flow Logs
```bash
aws logs describe-log-streams \
  --log-group-name /aws/vpc/eks-d-flow-logs \
  --order-by LastEventTime \
  --descending
```
