#!/bin/bash
set -e

# EKS-D + Karpenter AMI Installation Script
# This runs once during AMI build, not on each instance launch

echo "==> Updating system..."
sudo dnf update -y

echo "==> Installing base dependencies..."
sudo dnf install -y curl wget tar gzip jq git

echo "==> Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "==> Installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/

echo "==> Installing Helm..."
curl -fsSL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xz -C /tmp
sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm

echo "==> Installing Karpenter..."
# Install Karpenter CRDs and controller
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.0/crds/karpenter.sh_nodepools.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.0/crds/karpenter.k8s.aws_ec2nodeclasses.yaml

# Install Karpenter controller (will be configured via Helm at runtime)
# Note: We install the binary but configure via user data at launch

echo "==> Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "==> Installing Docker (for containerd)..."
sudo dnf install -y docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

echo "==> Pre-pull Karpenter container images..."
# Pre-pull to speed up first node provisioning
sudo ctr image pull registry.k8s.io/kubelet/kube-proxy:v1.29.0
sudo ctr image pull public.ecr.aws/eks-distro/kubernetes/pause:3.9
sudo ctr image pull public.ecr.aws/eks-distro/coredns/coredns:v1.29.0

echo "==> Cleaning up..."
rm -rf awscliv2.zip aws /tmp/install.sh

echo "==> AMI build complete!"
