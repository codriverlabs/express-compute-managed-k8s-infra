#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
CLUSTER_NAME="${2:-${DEVELOPER_SIGNUM}-eks-dx}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [cluster-name]"
  echo ""
  echo "Example: $0 alice"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Persist cluster identity so individual scripts can source it without args
sudo mkdir -p /opt/eks-d
cat <<EOF | sudo tee /opt/eks-d/cluster.env
DEVELOPER_SIGNUM="${DEVELOPER_SIGNUM}"
CLUSTER_NAME="${CLUSTER_NAME}"
EOF

echo "=========================================="
echo "EKS-D Complete Installation"
echo "=========================================="
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Cluster:   ${CLUSTER_NAME}"
echo "=========================================="
echo ""

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
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${DEVELOPER_SIGNUM}" "${CLUSTER_NAME}"

# Step 14: CloudWatch agent
echo "Step 14/14: Installing CloudWatch agent..."
CLUSTER_NAME="${CLUSTER_NAME}" bash "${SCRIPT_DIR}/13-install-cloudwatch.sh"

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify cluster: kubectl get nodes"
echo "2. Check Karpenter: kubectl get pods -n karpenter"
echo "3. Deploy NodePool: cd ../node-pools && ./configure-nodepools.sh ${DEVELOPER_SIGNUM}"
