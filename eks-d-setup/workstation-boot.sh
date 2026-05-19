#!/bin/bash
# workstation-boot.sh - EKS-DX Workstation Boot Script
# 
# This script is the entry point for AMI-based EKS-DX workstation deployment.
# It runs automatically via cloud-init user data and performs idempotent
# installation of EKS-D and all required components.

set -e

# Logging setup
BOOT_LOG="/var/log/eks-dx-boot.log"
exec > >(tee -a "$BOOT_LOG") 2>&1

echo "=========================================="
echo "EKS-DX Workstation Boot Started"
echo "Time: $(date)"
echo "=========================================="

# Check if installation already completed
if [ -f /opt/eks-d/.installation_complete ]; then
  echo "✓ EKS-DX installation already completed, skipping"
  exit 0
fi

# Ensure we have the required environment
if [ ! -f /opt/eks-d/cluster.env ]; then
  echo "Error: /opt/eks-d/cluster.env not found"
  echo "This file should be created by terraform user data"
  exit 1
fi

source /opt/eks-d/cluster.env
echo "Developer: ${DEVELOPER_SIGNUM}"
echo "Cluster: ${CLUSTER_NAME}"

# Verify installation scripts are available
if [ ! -d /opt/eks-d-setup ]; then
  echo "Error: /opt/eks-d-setup directory not found"
  echo "Installation scripts should be copied during AMI build"
  exit 1
fi

# Run the complete installation
echo "Starting EKS-D installation..."
cd /opt/eks-d-setup
./install-all.sh "${DEVELOPER_SIGNUM}" 2>&1 | tee /var/log/eks-dx-install-all.log

# Mark installation as complete
touch /opt/eks-d/.installation_complete
echo "$(date): Installation completed successfully" >> /opt/eks-d/.installation_complete

echo "=========================================="
echo "✓ EKS-DX Workstation Boot Completed"
echo "Time: $(date)"
echo "=========================================="

# Display cluster status
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
kubectl get pods -A | grep -E "(Running|Ready)"
