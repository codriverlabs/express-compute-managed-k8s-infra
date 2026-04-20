#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
CLUSTER_NAME="${2:-${DEVELOPER_SIGNUM}-eks-d}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [cluster-name]"
  echo ""
  echo "Example: $0 alice"
  exit 1
fi

# Check if installation is already complete
INSTALLATION_MARKER="/opt/eks-d/.installation_complete"
if [ -f "$INSTALLATION_MARKER" ]; then
  echo "=========================================="
  echo "EKS-D Installation Already Complete"
  echo "=========================================="
  echo "Installation completed at: $(cat $INSTALLATION_MARKER)"
  echo "Skipping user data execution."
  echo ""
  echo "Current cluster status:"
  kubectl get nodes 2>/dev/null || echo "Cluster may be starting up..."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Persist cluster identity
sudo mkdir -p /opt/eks-d
cat <<EOF | sudo tee /opt/eks-d/cluster.env
DEVELOPER_SIGNUM="${DEVELOPER_SIGNUM}"
CLUSTER_NAME="${CLUSTER_NAME}"
EOF

echo "=========================================="
echo "EKS-D Workstation Boot Configuration"
echo "=========================================="
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Cluster:   ${CLUSTER_NAME}"
echo "=========================================="
echo ""

# Step 1: Prepare etcd volume (format if needed)
echo "Step 1/8: Preparing etcd volume..."
bash "${SCRIPT_DIR}/05-prepare-etcd.sh"

# Step 2: Initialize EKS-D cluster
echo "Step 2/8: Initializing EKS-D cluster..."
bash "${SCRIPT_DIR}/06-install-eks-d.sh"

# Step 3: Install CNI
echo "Step 3/8: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 4: Install Cloud Provider
echo "Step 4/8: Installing AWS Cloud Provider..."
bash "${SCRIPT_DIR}/08-install-cloud-provider.sh"

# Step 5: Configure control plane node
echo "Step 5/8: Configuring control plane..."
bash "${SCRIPT_DIR}/09-configure-node.sh"

# Step 6: Install EBS CSI Driver
echo "Step 6/8: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/10-install-ebs-csi.sh"

# Step 7: Install Karpenter
echo "Step 7/8: Installing Karpenter..."
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${DEVELOPER_SIGNUM}" "${CLUSTER_NAME}"

# Step 8: Install CloudWatch agent
echo "Step 8/8: Installing CloudWatch agent..."
CLUSTER_NAME="${CLUSTER_NAME}" bash "${SCRIPT_DIR}/13-install-cloudwatch.sh"

# Mark installation as complete
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')" | sudo tee "$INSTALLATION_MARKER" > /dev/null
echo "Installation marker created at: $INSTALLATION_MARKER"

echo ""
echo "=========================================="
echo "✓ Workstation Configuration Complete!"
echo "=========================================="
echo ""
echo "Cluster Status:"
kubectl get nodes
kubectl get pods -A
echo ""
echo "Next steps:"
echo "1. Deploy NodePool: cd ../node-pools && ./configure-nodepools.sh ${DEVELOPER_SIGNUM}"
