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
echo "Step 1/9: Preparing etcd volume..."
bash "${SCRIPT_DIR}/05-prepare-etcd.sh"

# Step 2: Configure aws-iam-authenticator (must run before kubeadm init)
echo "Step 2/9: Configuring aws-iam-authenticator..."
bash "${SCRIPT_DIR}/05b-install-aws-iam-authenticator.sh"

# Step 3: Initialize EKS-D cluster
echo "Step 3/9: Initializing EKS-D cluster..."
bash "${SCRIPT_DIR}/06-install-eks-d.sh"

# Step 4: Install CNI
echo "Step 4/9: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 5: Install Cloud Provider
echo "Step 5/9: Installing AWS Cloud Provider..."
bash "${SCRIPT_DIR}/08-install-cloud-provider.sh"

# Step 6: Configure control plane node
echo "Step 6/9: Configuring control plane..."
bash "${SCRIPT_DIR}/09-configure-node.sh"

# Step 7: Install EBS CSI Driver
echo "Step 7/10: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/10-install-ebs-csi.sh"

# Step 8: Metrics Server
echo "Step 8/10: Installing Metrics Server..."
bash "${SCRIPT_DIR}/12-install-metrics-server.sh"

# Step 9: Install Karpenter
echo "Step 9/10: Installing Karpenter..."
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${DEVELOPER_SIGNUM}" "${CLUSTER_NAME}"

# Step 10: Install CloudWatch agent
echo "Step 10/10: Installing CloudWatch agent..."
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
