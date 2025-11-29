# CloudFormation Deployment Guide

This directory contains CloudFormation templates migrated from Terraform for deploying the EKS-D infrastructure.

## Files

- `cloudformation-template.yaml` - Main CloudFormation template
- `cloudformation-parameters.json` - Parameter values
- `deploy-cloudformation.sh` - Deployment script

## Quick Start

1. **Edit parameters**:
   ```bash
   vi cloudformation-parameters.json
   ```
   Update:
   - `TeamMemberName`: Your name (lowercase, hyphens only)
   - `KeyPairName`: Your EC2 key pair name
   - `SSHCidrBlock`: Your IP for SSH access (optional)

2. **Deploy**:
   ```bash
   ./deploy-cloudformation.sh my-stack-name us-east-1
   ```

3. **Check outputs**:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name my-stack-name \
     --query 'Stacks[0].Outputs' \
     --output table
   ```

## Manual Deployment

```bash
aws cloudformation create-stack \
  --stack-name eks-d-stack \
  --template-body file://cloudformation-template.yaml \
  --parameters file://cloudformation-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Update Stack

```bash
aws cloudformation update-stack \
  --stack-name eks-d-stack \
  --template-body file://cloudformation-template.yaml \
  --parameters file://cloudformation-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Delete Stack

```bash
aws cloudformation delete-stack \
  --stack-name eks-d-stack \
  --region us-east-1
```

## Key Differences from Terraform

- **State Management**: CloudFormation manages state automatically
- **Outputs**: Use `aws cloudformation describe-stacks` instead of `terraform output`
- **Updates**: CloudFormation creates change sets automatically
- **Rollback**: Automatic rollback on failure (can be disabled)

## Resources Created

Same as Terraform:
- VPC with public/private subnets
- NAT Gateway and Internet Gateway
- Security groups for control plane and workers
- IAM roles and policies for Karpenter
- EC2 instance for control plane
- All necessary tags for Karpenter discovery
