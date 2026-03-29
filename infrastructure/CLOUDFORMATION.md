# CloudFormation Deployment Guide

This directory contains CloudFormation templates for deploying the EKS-D infrastructure.

## Architecture

The deployment uses a hub-and-spoke model:
- **Shared VPC**: Single VPC shared by all developers (cost-effective, better networking)
- **Per-developer stacks**: Each developer gets their own CloudFormation stack with:
  - Dedicated public/private subnets within the shared VPC
  - EC2 instance for EKS-D control plane
  - Security groups scoped to the developer
  - IAM roles with least-privilege permissions
  - Karpenter for node management

## Quick Start

### 1. Deploy Shared VPC (one-time setup)
```bash
./deploy-vpc.sh us-east-1
```

### 2. Deploy Developer Stack
```bash
./deploy-developer.sh alice 1
```

### 3. Deploy with custom parameters
```bash
./deploy-developer.sh bob 2 my-key-pair true
```

## Templates

### Shared VPC Template (`shared-vpc-template.yaml`)
- Creates shared VPC with public/private subnets
- Sets up NAT gateway, internet gateway, route tables
- Creates VPC endpoints for AWS services
- Sets up VPC Flow Logs for monitoring

### Developer Stack Template (`developer-stack-template.yaml`)
- Developer-specific public/private subnets
- EC2 instance for EKS-D control plane
- Security groups with least-privilege rules
- IAM roles with tag-based permissions
- Karpenter IAM policies with resource tagging

## Security

- **Least Privilege IAM**: All IAM policies are scoped to developer resources
- **Network Security**: Security groups with minimal required ports
- **IMDSv2**: EC2 instances require IMDSv2
- **Encryption**: All EBS volumes encrypted at rest
- **Tagging**: All resources tagged with developer and environment

## Cost Optimization

- Shared VPC reduces networking costs
- Spot instances for worker nodes via Karpenter
- Auto-scaling based on workload
- Reserved instances for control plane (Compute Savings Plan)

## Monitoring

- VPC Flow Logs for network traffic
- CloudWatch metrics and alarms
- S3 access logging
- CloudTrail for API auditing

## Cleanup

To delete a developer's stack:
```bash
aws cloudformation delete-stack --stack-name eks-d-alice --region us-east-1
```

To delete the shared VPC (after all developer stacks are deleted):
```bash
aws cloudformation delete-stack --stack-name eks-d-shared-vpc --region us-east-1
```
