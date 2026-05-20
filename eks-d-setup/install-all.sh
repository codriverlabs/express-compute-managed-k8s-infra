#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
# Default cluster name includes arch so arm64/x86_64 workstations don't collide
_ARCH="$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/')"
CLUSTER_NAME="${2:-${DEVELOPER_SIGNUM}-eks-dx-${_ARCH}}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [cluster-name]"
  echo ""
  echo "Example: $0 alice"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Persist cluster identity and calculate common AWS variables once
sudo mkdir -p /opt/eks-d

# Calculate AWS metadata once using IMDSv2
echo "Calculating AWS environment variables..."
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null) || TOKEN=""

if [ -n "$TOKEN" ]; then
  AWS_ACCOUNT_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['accountId'])" 2>/dev/null) || AWS_ACCOUNT_ID=""
  AWS_REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null) || AWS_REGION=""
  INSTANCE_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null) || INSTANCE_ID=""
else
  echo "Warning: Could not get IMDS token, trying fallback methods..."
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || AWS_ACCOUNT_ID=""
  AWS_REGION=$(aws configure get region 2>/dev/null) || AWS_REGION="us-east-1"
  INSTANCE_ID=""
fi

# Fallback for region if still empty
if [ -z "$AWS_REGION" ] || [ "$AWS_REGION" = "None" ]; then
  AWS_REGION="us-east-1"
fi

# Derive other common variables
NODE_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${DEVELOPER_SIGNUM}-eks-dx-${_ARCH}"
CLUSTER_ENDPOINT="https://$(hostname -I | awk '{print $1}'):6443"

# Create comprehensive environment file
cat <<EOF | sudo tee /opt/eks-d/cluster.env
# Cluster Identity
DEVELOPER_SIGNUM="${DEVELOPER_SIGNUM}"
CLUSTER_NAME="${CLUSTER_NAME}"

# AWS Environment (calculated once)
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
AWS_REGION="${AWS_REGION}"
INSTANCE_ID="${INSTANCE_ID}"

# Derived Variables
NODE_ROLE_ARN="${NODE_ROLE_ARN}"
CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT}"

# Calculated at: $(date)
EOF

echo "✓ Environment variables calculated and persisted to /opt/eks-d/cluster.env"
echo "  AWS Account: ${AWS_ACCOUNT_ID}"
echo "  AWS Region: ${AWS_REGION}"
echo "  Instance ID: ${INSTANCE_ID}"
echo "  Node Role: ${NODE_ROLE_ARN}"

echo "=========================================="
echo "EKS-D Complete Installation"
echo "=========================================="
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Cluster:   ${CLUSTER_NAME}"
echo "=========================================="
echo ""

# AMI_PATH=1 skips steps 1-5 (binaries/config already baked into AMI)
AMI_PATH="${AMI_PATH:-0}"

if [ "$AMI_PATH" != "1" ]; then
  # Step 1: Base system
  echo "Step 1/14: Installing base system..."
  bash "${SCRIPT_DIR}/01-install-base.sh"

  # Step 2: containerd
  echo "Step 2/14: Installing containerd..."
  bash "${SCRIPT_DIR}/02-install-docker.sh"

  # Step 3: Configure containerd (must run after containerd is installed)
  echo "Step 3/14: Configuring containerd..."
  bash "${SCRIPT_DIR}/00-configure-containerd.sh"

  # Step 4: Helm
  echo "Step 4/14: Installing Helm..."
  bash "${SCRIPT_DIR}/04-install-helm.sh"

  # Step 5: etcd volume
  echo "Step 5/14: Preparing etcd volume..."
  bash "${SCRIPT_DIR}/05-prepare-etcd.sh"
else
  echo "AMI path — skipping steps 1-4 (pre-baked); running etcd volume setup..."
  bash "${SCRIPT_DIR}/05-prepare-etcd.sh"
fi

# Step 6: aws-iam-authenticator (must run before kubeadm init)
echo "Step 6/14: Configuring aws-iam-authenticator..."
bash "${SCRIPT_DIR}/05b-install-aws-iam-authenticator.sh"

# Step 7: EKS-D (kubeadm init with EKS-D images + cloud-provider:external)
# Note: also installs the EKS-D kubectl binary
echo "Step 7/14: Installing EKS-D..."
bash "${SCRIPT_DIR}/06-install-eks-d.sh"

# Step 8: AWS VPC CNI
echo "Step 8/14: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 9: AWS Cloud Controller Manager (sets node ProviderID, required by Karpenter)
echo "Step 9/14: Installing AWS Cloud Provider..."
bash "${SCRIPT_DIR}/08-install-cloud-provider.sh"

# Step 10: Untaint control plane
echo "Step 10/14: Configuring control plane..."
bash "${SCRIPT_DIR}/09-configure-node.sh"

# Step 11: EBS CSI Driver
echo "Step 11/14: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/10-install-ebs-csi.sh"

# Step 12: Metrics Server
echo "Step 12/14: Installing Metrics Server..."
bash "${SCRIPT_DIR}/12-install-metrics-server.sh"

# Step 13: Karpenter
echo "Step 13/14: Installing Karpenter..."
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${DEVELOPER_SIGNUM}" "${CLUSTER_NAME}" 2>&1 | tee /tmp/11-install-karpenter.log

# Step 14: CloudWatch agent
echo "Step 14/14: Installing CloudWatch agent..."
CLUSTER_NAME="${CLUSTER_NAME}" bash "${SCRIPT_DIR}/13-install-cloudwatch.sh" 2>&1 | tee /tmp/13-install-cloudwatch.log

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify cluster: kubectl get nodes"
echo "2. Check Karpenter: kubectl get pods -n karpenter"
echo "3. Deploy NodePool: cd ../node-pools && ./configure-nodepools.sh ${DEVELOPER_SIGNUM}"
