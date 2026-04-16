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

# Step 0: Configure containerd (EKS-D pause image + SystemdCgroup)
echo "Step 0/11: Configuring containerd..."
bash "${SCRIPT_DIR}/00-configure-containerd.sh"

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

# Step 6: EKS-D (kubeadm init with EKS-D images + cloud-provider:external)
echo "Step 6/11: Installing EKS-D..."
bash "${SCRIPT_DIR}/06-install-eks-d.sh"

# Step 7: AWS VPC CNI
echo "Step 7/11: Installing AWS VPC CNI..."
bash "${SCRIPT_DIR}/07-install-cni.sh"

# Step 8: AWS Cloud Controller Manager (sets node ProviderID, required by Karpenter)
echo "Step 8/11: Installing AWS Cloud Provider..."
bash "${SCRIPT_DIR}/08-install-cloud-provider.sh"

# Step 8: EBS CSI Driver
echo "Step 8/11: Installing EBS CSI Driver..."
bash "${SCRIPT_DIR}/09-install-ebs-csi.sh"

# Step 9: Untaint control plane
echo "Step 9/11: Configuring control plane..."
bash "${SCRIPT_DIR}/10-configure-node.sh"

# Step 10: Karpenter
echo "Step 10/11: Installing Karpenter..."
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
