#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
STACK_NAME="eks-d-${DEVELOPER_SIGNUM}"
REGION="${2:-us-east-1}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [region]"
  echo ""
  echo "Example: $0 alice"
  exit 1
fi

echo "=========================================="
echo "Configuring Karpenter NodePools"
echo "=========================================="
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Stack:     ${STACK_NAME}"
echo "Region:    ${REGION}"
echo "=========================================="
echo ""

# Get cluster name
CLUSTER_NAME=$(aws ssm get-parameter \
  --name "/eks-d/${DEVELOPER_SIGNUM}/cluster-name" \
  --query 'Parameter.Value' \
  --output text \
  --region "${REGION}")

# Get subnet ID
PRIVATE_SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' \
  --output text \
  --region "${REGION}")

# Get security group ID
WORKER_SG_ID=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkerSecurityGroupId`].OutputValue' \
  --output text \
  --region "${REGION}")

echo "Cluster Name:      ${CLUSTER_NAME}"
echo "Private Subnet:    ${PRIVATE_SUBNET_ID}"
echo "Security Group:    ${WORKER_SG_ID}"
echo ""

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
    - id: ${PRIVATE_SUBNET_ID}
  securityGroupSelectorTerms:
    - id: ${WORKER_SG_ID}
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
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "c"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["3"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: "100"
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF

echo ""
echo "✓ NodePools configured"
echo ""
kubectl get nodepool
kubectl get ec2nodeclass
