#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
REGION="${2:-us-east-1}"
STACK_NAME="eks-d-${DEVELOPER_SIGNUM}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [region]"
  exit 1
fi

echo "=========================================="
echo "Configuring Karpenter NodePools for $DEVELOPER_SIGNUM"
echo "=========================================="

# Get CloudFormation outputs
echo "Getting CloudFormation outputs..."
CLUSTER_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
  --output text \
  --region "$REGION" \
  2>/dev/null || echo "${DEVELOPER_SIGNUM}-eks-d")

PRIVATE_SUBNET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' \
  --output text \
  --region "$REGION")

WORKER_SG=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkerSecurityGroupId`].OutputValue' \
  --output text \
  --region "$REGION")

INSTANCE_PROFILE=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkerNodeInstanceProfile`].OutputValue' \
  --output text \
  --region "$REGION")

echo "Cluster: $CLUSTER_NAME"
echo "Private Subnet: $PRIVATE_SUBNET"
echo "Worker Security Group: $WORKER_SG"
echo "Instance Profile: $INSTANCE_PROFILE"

# Create EC2NodeClass
echo "Creating EC2NodeClass..."
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: ${DEVELOPER_SIGNUM}-eks-d-worker-node-role
  subnetSelectorTerms:
    - id: ${PRIVATE_SUBNET}
  securityGroupSelectorTerms:
    - id: ${WORKER_SG}
  tags:
    Developer: ${DEVELOPER_SIGNUM}
    karpenter.sh/cluster: ${CLUSTER_NAME}
    ManagedBy: Karpenter
EOF

# Create NodePool
echo "Creating NodePool..."
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        karpenter.sh/nodepool: default
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "c"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["3"]
        - key: karpenter.k8s.aws/instance-cpu
          operator: Gt
          values: ["2"]
        - key: karpenter.k8s.aws/instance-memory
          operator: Gt
          values: ["2048"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
  limits:
    cpu: 100
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF

echo ""
echo "✓ NodePool configured for $DEVELOPER_SIGNUM"
echo "Karpenter is ready to provision nodes on-demand."
echo ""
echo "To test, deploy a workload with:"
echo "kubectl create deployment nginx --image=nginx"
echo "kubectl scale deployment nginx --replicas=5"
