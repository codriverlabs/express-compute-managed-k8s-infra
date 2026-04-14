#!/bin/bash
set -e

# EKS-D AMI Installation Script
# Pre-installs binaries, images, and scripts for fast workstation boot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EKS_D_SETUP_DIR="$(cd "${SCRIPT_DIR}/../../eks-d-setup" && pwd)"

export AMI_BUILD=true

echo "==> Installing base system..."
bash "${EKS_D_SETUP_DIR}/01-install-base.sh"

echo "==> Installing Docker..."
bash "${EKS_D_SETUP_DIR}/02-install-docker.sh"

echo "==> Installing kubectl..."
bash "${EKS_D_SETUP_DIR}/03-install-kubectl.sh"

echo "==> Installing Helm..."
bash "${EKS_D_SETUP_DIR}/04-install-helm.sh"

echo "==> Installing EKS-D binaries..."
bash "${EKS_D_SETUP_DIR}/06-install-eks-d.sh"

# Copy eks-d-setup scripts to AMI for use at boot time
echo "==> Installing eks-d-setup scripts..."
sudo mkdir -p /opt/eks-d-setup
sudo cp -r "${EKS_D_SETUP_DIR}"/* /opt/eks-d-setup/
sudo chmod +x /opt/eks-d-setup/*.sh

# Pre-pull container images
echo "==> Pre-pulling container images..."
sudo systemctl start containerd
sudo ctr images pull registry.k8s.io/kube-proxy:v1.29.0 || true
sudo ctr images pull registry.k8s.io/coredns/coredns:v1.29.0 || true
sudo ctr images pull registry.k8s.io/pause:3.9 || true
sudo ctr images pull public.ecr.aws/karpenter/controller:v1.10.0 || true

echo ""
echo "==> AMI build complete!"
echo "    Scripts installed to /opt/eks-d-setup/"
echo "    Binaries and images pre-installed for fast boot."
