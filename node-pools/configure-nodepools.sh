#!/bin/bash
set -e

# Load cluster identity
[ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env

DEVELOPER_SIGNUM="${1:-${DEVELOPER_SIGNUM}}"
REGION="${2:-${AWS_REGION:-us-east-1}}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [region]"
  exit 1
fi

CLUSTER_NAME="${CLUSTER_NAME:-${DEVELOPER_SIGNUM}-eks-d}"

echo "Configuring Karpenter NodePools for $DEVELOPER_SIGNUM (cluster: $CLUSTER_NAME)"

# Discover resources from Terraform outputs
INSTANCE_PROFILE=$(aws iam list-instance-profiles-for-role \
  --role-name "eks-d-workstation-${DEVELOPER_SIGNUM}" \
  --query 'InstanceProfiles[0].InstanceProfileName' \
  --output text --region "$REGION" 2>/dev/null || echo "eks-d-workstation-${DEVELOPER_SIGNUM}")

PRIVATE_SUBNET=$(aws ec2 describe-subnets \
  --filters "Name=tag:Developer,Values=${DEVELOPER_SIGNUM}" "Name=tag:SubnetType,Values=Private" \
  --query 'Subnets[0].SubnetId' --output text --region "$REGION")

SECURITY_GROUP=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=eks-d-workstation-${DEVELOPER_SIGNUM}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "$REGION")

# Discover EKS-D worker AMI (same AMI as control plane)
AMI_ID=$(aws ssm get-parameter \
  --name "/eks-d/ami/arm64" \
  --query 'Parameter.Value' --output text --region "$REGION" 2>/dev/null || \
  aws ssm get-parameter \
  --name "/eks-d/ami/x86_64" \
  --query 'Parameter.Value' --output text --region "$REGION")

echo "  Instance Profile : $INSTANCE_PROFILE"
echo "  Private Subnet   : $PRIVATE_SUBNET"
echo "  Security Group   : $SECURITY_GROUP"
echo "  AMI              : $AMI_ID"

# EC2NodeClass — use instanceProfile (not role) since IAM has no VPC endpoint
# See: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/#private-clusters
kubectl apply -f - <<EOF
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # Use instanceProfile instead of role — IAM API has no VPC endpoint
  instanceProfile: "${INSTANCE_PROFILE}"

  # Pin to the EKS-D AMI; amiFamily Custom requires explicit userData
  amiSelectorTerms:
    - id: "${AMI_ID}"

  subnetSelectorTerms:
    - id: "${PRIVATE_SUBNET}"

  securityGroupSelectorTerms:
    - id: "${SECURITY_GROUP}"

  # Worker node bootstrap for EKS-D (joins existing kubeadm cluster)
  userData: |
    #!/bin/bash
    set -e
    CLUSTER_NAME="${CLUSTER_NAME}"
    DEVELOPER_SIGNUM="${DEVELOPER_SIGNUM}"
    cd /opt/eks-d-setup
    bash ./00-configure-containerd.sh
    bash ./09-configure-node.sh

  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required

  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  tags:
    Developer: "${DEVELOPER_SIGNUM}"
    "kubernetes.io/cluster/${CLUSTER_NAME}": "owned"
    ManagedBy: Karpenter
EOF

# NodePool
kubectl apply -f - <<EOF
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
    cpu: 100
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF

echo "✓ NodePool configured. Karpenter will provision arm64 spot nodes on demand."
