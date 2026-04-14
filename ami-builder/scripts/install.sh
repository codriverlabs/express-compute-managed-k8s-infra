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

# Pre-download Helm charts and manifests
echo "==> Pre-downloading Helm charts..."
helm repo add karpenter https://charts.karpenter.sh
helm repo update
helm pull karpenter/karpenter --version "1.8.2" --destination /tmp || true
sudo mkdir -p /opt/eks-d/charts
sudo mv /tmp/karpenter-*.tgz /opt/eks-d/charts/ 2>/dev/null || true

echo "==> Pre-downloading manifests..."
sudo mkdir -p /opt/eks-d/manifests
sudo curl -sL "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml" \
  -o /opt/eks-d/manifests/aws-vpc-cni.yaml
sudo curl -sL "https://github.com/kubernetes/kubernetes/raw/release-1.29/cluster/addons/dns/coredns.yaml" \
  -o /opt/eks-d/manifests/coredns.yaml || true

echo ""
echo "==> AMI build complete!"
echo "    Scripts installed to /opt/eks-d-setup/"
echo "    Binaries and images pre-installed for fast boot."
