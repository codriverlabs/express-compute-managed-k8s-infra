# Developer Onboarding Guide

This guide helps new developers get their EKS-D environment set up.

## Prerequisites

- AWS CLI installed and configured
- Access to the AWS account
- Assigned subnet index (get from admin)

## Step 1: Generate Your Key Pair

Each developer needs their own EC2 key pair for SSH access.

```bash
cd infrastructure

# Generate key pair (replace 'alice' with your signum)
./generate-keypair.sh alice

# This creates:
# - AWS key pair: alice-eks-d-key
# - Local file: ~/.ssh/alice-eks-d-key.pem
```

**Important:** Keep your private key file safe! It cannot be recovered if lost.

## Step 2: Deploy Your Environment

### Option A: Auto-generate Key (Simplest)

```bash
# Deploy with auto-generated key pair
./deploy-developer.sh alice 1

# Parameters:
# - alice: your developer signum
# - 1: your assigned subnet index (get from admin)
```

### Option B: Use Existing Key

```bash
# Deploy with existing key pair
./deploy-developer.sh alice 1 alice-eks-d-key false

# Parameters:
# - alice: your developer signum
# - 1: your assigned subnet index
# - alice-eks-d-key: your key pair name
# - false: disable user data for manual setup
```

## Step 3: Wait for Deployment

The deployment takes 5-10 minutes. You'll see:
- Stack creation progress
- SSH command
- Kubernetes API endpoint

## Step 4: Connect to Your Instance

```bash
# Use the SSH command from deployment output
ssh -i ~/.ssh/alice-eks-d-key.pem ec2-user@<your-elastic-ip>
```

## Step 5: Manual Setup (if user data disabled)

If you deployed with `enable-userdata=false`, follow the manual setup guide:

```bash
# On your local machine
cat infrastructure/MANUAL_SETUP.md

# Then SSH to your instance and follow the steps
```

## Step 6: Verify Your Environment

```bash
# Check Kubernetes cluster
kubectl get nodes

# Check Karpenter
kubectl get pods -n karpenter

# Check your resources are tagged correctly
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=alice" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags]'
```

## Your Resources

Each developer gets:

### Network
- **Public Subnet**: 10.0.{index}.0/24
- **Private Subnet**: 10.0.{100+index}.0/24
- **Elastic IP**: Static IP for SSH access

### Compute
- **Control Plane**: t4g.large instance
- **Worker Nodes**: Managed by Karpenter (Spot instances)

### Security
- **Security Groups**: Isolated per developer
- **IAM Roles**: Scoped to your resources only
- **Tags**: All resources tagged with your name

## Daily Operations

### Start Your Day

```bash
# Check if instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=alice" \
           "Name=instance-state-name,Values=running"

# SSH to instance
ssh -i ~/.ssh/alice-eks-d-key.pem ec2-user@<your-elastic-ip>

# Check cluster status
kubectl get nodes
```

### Deploy Test Workload

```bash
# Scale up test deployment
kubectl scale deployment inflate --replicas=5

# Watch Karpenter provision nodes
kubectl get nodes -w

# Check worker nodes
kubectl get nodes -o wide
```

### End Your Day

```bash
# Scale down workloads
kubectl scale deployment inflate --replicas=0

# Wait for Karpenter to deprovision nodes
kubectl get nodes -w

# Stop control plane instance (optional, saves cost)
aws ec2 stop-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Developer,Values=alice" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
```

## Cost Management

### Your Monthly Costs

- **Control Plane** (t4g.large): ~$10.75/month (8h/day, 5 days/week)
- **Elastic IP** (when stopped): ~$2.48/month
- **EBS Volumes**: ~$5/month
- **Worker Nodes**: Pay only when running (Spot pricing)

**Total**: ~$18-25/month depending on worker node usage

### Cost Optimization Tips

1. **Stop instances when not in use**
   ```bash
   aws ec2 stop-instances --instance-ids <your-instance-id>
   ```

2. **Scale down workloads**
   ```bash
   kubectl scale deployment --all --replicas=0
   ```

3. **Monitor your spending**
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2025-01-01,End=2025-01-31 \
     --granularity MONTHLY \
     --metrics BlendedCost \
     --group-by Type=TAG,Key=Developer \
     --filter file://<(echo '{"Tags":{"Key":"Developer","Values":["alice"]}}')
   ```

## Troubleshooting

### Can't SSH to instance

```bash
# Check instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=alice" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]'

# Check security group allows your IP
aws ec2 describe-security-groups \
  --filters "Name=tag:Developer,Values=alice" \
  --query 'SecurityGroups[].IpPermissions'
```

### Karpenter not provisioning nodes

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# Check NodePool
kubectl describe nodepool default

# Check IAM permissions
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i "access denied"
```

### Worker nodes in wrong subnet

```bash
# Verify your private subnet
aws cloudformation describe-stacks \
  --stack-name eks-d-alice \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' \
  --output text

# Check where nodes are running
kubectl get nodes -o wide
```

## Getting Help

1. **Check logs**: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter`
2. **Review security docs**: `cat infrastructure/SECURITY.md`
3. **Contact admin**: Provide your developer signum and error details

## Cleanup

When you're done with your environment:

```bash
# Delete your stack
aws cloudformation delete-stack --stack-name eks-d-alice

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name eks-d-alice

# Delete your key pair (optional)
aws ec2 delete-key-pair --key-name alice-eks-d-key
rm ~/.ssh/alice-eks-d-key.pem
```

## Best Practices

1. **Tag everything**: All resources should have your Developer tag
2. **Use Spot instances**: Configure Karpenter for Spot capacity
3. **Stop when idle**: Stop control plane when not working
4. **Monitor costs**: Check AWS Cost Explorer weekly
5. **Keep keys safe**: Never commit private keys to git
6. **Follow naming**: Use `{signum}-{resource}` format
7. **Test isolation**: Verify you can't access other developers' resources
