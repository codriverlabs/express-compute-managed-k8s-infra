#!/bin/bash
# setup-eks-d.sh - Boot-time EKS-D cluster setup
#
# Assumes AMI-baked prerequisites are already present:
#   containerd, helm, kubectl, kubeadm, kubelet, ECR credential provider,
#   all container images pre-pulled.
#
# Runs: etcd volume → iam-authenticator → kubeadm init → CNI → CCM →
#       node config → EBS CSI → metrics-server → Karpenter → CloudWatch
set -eo pipefail

TENANT_ID="${1}"
_ARCH="$(uname -m | sed 's/aarch64/arm64/')"
CLUSTER_NAME="${2:-${TENANT_ID}-eks-dx-${_ARCH}}"

if [ -z "$TENANT_ID" ]; then
  echo "Usage: $0 <tenant-id> [cluster-name]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Persist cluster identity and AWS environment ──────────────────────────────
sudo mkdir -p /opt/eks-d

echo "Calculating AWS environment variables..."
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null) || TOKEN=""

if [ -n "$TOKEN" ]; then
  AWS_ACCOUNT_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['accountId'])") || AWS_ACCOUNT_ID=""
  AWS_REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null) || AWS_REGION=""
  INSTANCE_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null) || INSTANCE_ID=""
else
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || AWS_ACCOUNT_ID=""
  AWS_REGION=$(aws configure get region 2>/dev/null) || AWS_REGION="us-east-1"
  INSTANCE_ID=""
fi

[ -z "$AWS_REGION" ] || [ "$AWS_REGION" = "None" ] && AWS_REGION="us-east-1"

NODE_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${TENANT_ID}-eks-dx-${_ARCH}"
CLUSTER_ENDPOINT="https://$(hostname -I | awk '{print $1}'):6443"

cat <<EOF | sudo tee /opt/eks-d/cluster.env
TENANT_ID="${TENANT_ID}"
CLUSTER_NAME="${CLUSTER_NAME}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
AWS_REGION="${AWS_REGION}"
INSTANCE_ID="${INSTANCE_ID}"
NODE_ROLE_ARN="${NODE_ROLE_ARN}"
CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT}"
EOF

echo "✓ cluster.env written (account=${AWS_ACCOUNT_ID}, region=${AWS_REGION})"

echo "=========================================="
echo "EKS-D Cluster Setup"
echo "Developer: ${TENANT_ID}  Cluster: ${CLUSTER_NAME}"
echo "=========================================="

# Step 1: etcd volume (EBS attached at instance launch)
echo "Step 1/10: Preparing etcd volume..."
bash "${SCRIPT_DIR}/05-prepare-etcd.sh"

# Step 2: aws-iam-authenticator config (must precede kubeadm init)
echo "Step 2/10: Configuring aws-iam-authenticator..."
bash "${SCRIPT_DIR}/05b-install-aws-iam-authenticator.sh"

# Step 3: kubeadm init
echo "Step 3/10: Initialising EKS-D cluster..."
bash "${SCRIPT_DIR}/06-install-eks-d.sh"

# Step 4: AWS VPC CNI
echo "Step 4/10: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 5: AWS Cloud Controller Manager
echo "Step 5/10: Installing AWS Cloud Provider..."
bash "${SCRIPT_DIR}/08-install-cloud-provider.sh"

# Step 6: Untaint control plane
echo "Step 6/10: Configuring control plane node..."
bash "${SCRIPT_DIR}/09-configure-node.sh"

# Step 6b: cert-manager (required by webhooks and observability)
echo "Step 6b: Installing cert-manager..."
bash "${SCRIPT_DIR}/09b-install-cert-manager.sh"

# Step 7: EBS CSI Driver
echo "Step 7/10: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/10-install-ebs-csi.sh"

# Step 8: Metrics Server
echo "Step 8/10: Installing Metrics Server..."
bash "${SCRIPT_DIR}/12-install-metrics-server.sh"

# Step 9: Karpenter
echo "Step 9/10: Installing Karpenter..."
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${TENANT_ID}" "${CLUSTER_NAME}"

# Step 10: CloudWatch
echo "Step 10/10: Installing CloudWatch agent..."
CLUSTER_NAME="${CLUSTER_NAME}" bash "${SCRIPT_DIR}/13-install-cloudwatch.sh"

echo ""
echo "=========================================="
echo "✓ EKS-D cluster setup complete!"
echo "=========================================="
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  cd ../node-pools && ./configure-nodepools.sh ${TENANT_ID}"
