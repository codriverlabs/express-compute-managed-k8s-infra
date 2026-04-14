#!/bin/bash
set -e

# EKS-D AMI Installation Script
# Pre-installs all components for fast workstation boot

echo "==> Updating system..."
sudo dnf update -y

echo "==> Installing base dependencies..."
sudo dnf install -y curl wget tar gzip jq git unzip

# =============================================================================
# Step 1-4: Base tools (from eks-d-setup)
# =============================================================================

echo "==> Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "==> Installing Helm..."
curl -fsSL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xz -C /tmp
sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm

echo "==> Installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/

# =============================================================================
# Step 5: Docker/containerd
# =============================================================================

echo "==> Installing Docker..."
sudo dnf install -y docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# =============================================================================
# Step 6: EKS-D binaries (pre-download, not configure)
# =============================================================================

echo "==> Pre-downloading EKS-D components..."
# EKS-D release version - will be configured at runtime
EKS_D_VERSION="v1.29-eks-d"
EKS_D_RELEASE="1"

# Download EKS-D binaries (will be configured via user-data)
mkdir -p /opt/eks-d/bin

# kube-apiserver, kube-controller-manager, kube-scheduler, etcd
# These are downloaded from EKS-D releases
curl -L "https://distro.eks.amazonaws.com/kubernetes-${EKS_D_VERSION}/releases/${EKS_D_RELEASE}/artifacts/kubernetes-server-linux-amd64.tar.gz" -o /tmp/kubernetes-server.tar.gz || true
tar -xzf /tmp/kubernetes-server.tar.gz -C /opt/eks-d/bin/ || true

# etcd
curl -L "https://distro.eks.amazonaws.com/kubernetes-${EKS_D_VERSION}/releases/${EKS_D_RELEASE}/artifacts/etcd-linux-amd64.tar.gz" -o /tmp/etcd.tar.gz || true
tar -xzf /tmp/etcd.tar.gz -C /opt/eks-d/bin/ || true

# =============================================================================
# Step 7: AWS CLI
# =============================================================================

echo "==> Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# =============================================================================
# Step 8: Pre-pull common container images
# =============================================================================

echo "==> Pre-pulling container images..."
sudo ctr images pull registry.k8s.io/kube-proxy:v1.29.0 || true
sudo ctr images pull registry.k8s.io/coredns/coredns:v1.29.0 || true
sudo ctr images pull registry.k8s.io/pause:3.9 || true

# Karpenter images (v1.10.0)
sudo ctr images pull public.ecr.aws/karpenter/controller:v1.10.0 || true

# =============================================================================
# Cleanup
# =============================================================================

echo "==> Cleaning up..."
rm -rf awscliv2.zip aws /tmp/*.tar.gz

echo "==> AMI build complete!"
echo "    EKS-D binaries: /opt/eks-d/bin/"
echo "    Runtime configuration via user-data"
