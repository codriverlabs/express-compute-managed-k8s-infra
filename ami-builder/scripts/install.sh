#!/bin/bash
set -e

# EKS-D AMI Installation Script
# Pre-installs binaries, images, and scripts for fast workstation boot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EKS_D_SETUP_DIR="/tmp/eks-d-setup"

# EKS-D version (must match 06-install-eks-d.sh)
EKSD_VERSION="1-33"
EKSD_RELEASE="19"

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

# Pre-download Helm charts and manifests FIRST (needed for image discovery)
echo "==> Pre-downloading Helm charts..."
helm repo add karpenter https://charts.karpenter.sh
helm repo update
helm pull karpenter/karpenter --version "v1.10.0" --destination /tmp || true
sudo mkdir -p /opt/eks-d/charts
sudo mv /tmp/karpenter-*.tgz /opt/eks-d/charts/ 2>/dev/null || true

echo "==> Pre-downloading manifests..."
sudo mkdir -p /opt/eks-d/manifests
sudo curl -sL "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml" \
  -o /opt/eks-d/manifests/aws-vpc-cni.yaml
sudo curl -sL "https://github.com/kubernetes/kubernetes/raw/release-1.29/cluster/addons/dns/coredns.yaml" \
  -o /opt/eks-d/manifests/coredns.yaml || true

# Pre-pull container images by inspecting charts and manifests
echo "==> Discovering and pre-pulling container images..."
sudo systemctl start containerd

# Pull images from kubeadm config (etcd, pause, kube-apiserver, etc.)
echo "==> Pulling kubeadm images..."
sudo kubeadm config images pull 2>/dev/null || true

# Render Karpenter chart and extract images
echo "==> Extracting and pulling images from Karpenter chart..."
KARPENTER_CHART=$(ls /opt/eks-d/charts/karpenter-*.tgz 2>/dev/null | head -1)
if [ -n "$KARPENTER_CHART" ]; then
  helm template karpenter "$KARPENTER_CHART" 2>/dev/null | \
    grep -oP 'image:\s*\K[^\s]+' | sort -u | while read img; do
      echo "  Pulling: $img"
      sudo ctr images pull "$img" || true
    done
fi

# Extract images from VPC CNI manifest
echo "==> Extracting and pulling images from VPC CNI manifest..."
if [ -f /opt/eks-d/manifests/aws-vpc-cni.yaml ]; then
  grep -oP 'image:\s*\K[^\s]+' /opt/eks-d/manifests/aws-vpc-cni.yaml | sort -u | while read img; do
    echo "  Pulling: $img"
    sudo ctr images pull "$img" || true
  done
fi

# Extract images from CoreDNS manifest
echo "==> Extracting and pulling images from CoreDNS manifest..."
if [ -f /opt/eks-d/manifests/coredns.yaml ]; then
  grep -oP 'image:\s*\K[^\s]+' /opt/eks-d/manifests/coredns.yaml | sort -u | while read img; do
    echo "  Pulling: $img"
    sudo ctr images pull "$img" || true
  done
fi

# EBS CSI driver - pull known images (kustomize is harder to render)
echo "==> Pulling EBS CSI driver images..."
sudo ctr images pull public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver:v1.53.0 || true
sudo ctr images pull public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner:v4.0.1-eks-1-29-latest || true
sudo ctr images pull public.ecr.aws/eks-distro/kubernetes-csi/external-attacher:v4.0.0-eks-1-29-latest || true
sudo ctr images pull public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe:v2.9.0-eks-1-29-latest || true
sudo ctr images pull public.ecr.aws/eks-distro/kubernetes-csi/external-resizer:v1.7.0-eks-1-29-latest || true

echo ""
echo "==> AMI build complete!"
echo "    Scripts installed to /opt/eks-d-setup/"
echo "    Charts installed to /opt/eks-d/charts/"
echo "    Manifests installed to /opt/eks-d/manifests/"
echo "    All images pre-pulled for fast boot."
