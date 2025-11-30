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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "EKS-D Complete Installation"
echo "=========================================="
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Cluster:   ${CLUSTER_NAME}"
echo "=========================================="
echo ""

# Step 1: Base system
echo "Step 1/11: Installing base system..."
bash "${SCRIPT_DIR}/01-install-base.sh"

# Step 2: Docker
echo "Step 2/11: Installing Docker..."
bash "${SCRIPT_DIR}/02-install-docker.sh"

# Step 3: kubectl
echo "Step 3/11: Installing kubectl..."
bash "${SCRIPT_DIR}/03-install-kubectl.sh"

# Step 4: Helm
echo "Step 4/11: Installing Helm..."
bash "${SCRIPT_DIR}/04-install-helm.sh"

# Step 5: etcd volume
echo "Step 5/11: Preparing etcd volume..."
bash "${SCRIPT_DIR}/05-prepare-etcd.sh"

# Step 6: Kubernetes
echo "Step 6/11: Installing Kubernetes..."
bash "${SCRIPT_DIR}/06-install-kubernetes.sh"

# Step 7: AWS VPC CNI
echo "Step 7/11: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 8: CoreDNS
echo "Step 8/11: Installing CoreDNS..."
bash "${SCRIPT_DIR}/08-install-coredns.sh"

# Step 9: EBS CSI Driver
echo "Step 9/11: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/09-install-ebs-csi.sh"

# Step 10: Untaint control plane
echo "Step 10/11: Configuring control plane..."
bash "${SCRIPT_DIR}/10-configure-node.sh"

# Step 11: Karpenter
echo "Step 11/11: Installing Karpenter..."
bash "${SCRIPT_DIR}/11-install-karpenter.sh" "${DEVELOPER_SIGNUM}" "${CLUSTER_NAME}"

echo ""
echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify cluster: kubectl get nodes"
echo "2. Check Karpenter: kubectl get pods -n karpenter"
echo "3. Deploy NodePool: cd ../node-pools && ./configure-nodepools.sh ${DEVELOPER_SIGNUM}"
