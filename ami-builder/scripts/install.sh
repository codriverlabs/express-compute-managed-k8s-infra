#!/bin/bash
set -e

# EKS-D AMI Installation Script
# Pre-installs ALL components for instant workstation boot

ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

# EKS-D version
EKSD_VERSION="1-33"
EKSD_RELEASE="19"

echo "==> Updating system..."
sudo dnf update -y

echo "==> Installing base dependencies via dnf..."
sudo dnf install -y docker awscli jq git unzip curl wget tar gzip

# =============================================================================
# Step 1: Install kubectl, helm, eksctl
# =============================================================================

echo "==> Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "==> Installing Helm..."
curl -fsSL https://get.helm.sh/helm-v3.14.0-linux-${ARCH}.tar.gz | tar -xz -C /tmp
sudo mv /tmp/linux-${ARCH}/helm /usr/local/bin/helm

echo "==> Installing eksctl..."
curl -sL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_${ARCH}.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/

# =============================================================================
# Step 2: Install Docker (via dnf on AL2023)
# =============================================================================

echo "==> Installing Docker..."
sudo dnf install -y docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# =============================================================================
# Step 3: Install EKS-D binaries (kubeadm, kubelet, kubectl)
# =============================================================================

echo "==> Downloading EKS-D release manifest..."
curl -sL "https://distro.eks.amazonaws.com/kubernetes-${EKSD_VERSION}/kubernetes-${EKSD_VERSION}-eks-${EKSD_RELEASE}.yaml" -o /tmp/eks-d-release.yaml

KUBEADM_URL=$(grep "bin/linux/${ARCH}/kubeadm" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBELET_URL=$(grep "bin/linux/${ARCH}/kubelet" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBECTL_URL=$(grep "bin/linux/${ARCH}/kubectl" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')

echo "==> Installing EKS-D binaries..."
curl -sL "${KUBEADM_URL}" -o /tmp/kubeadm
sudo install -o root -g root -m 0755 /tmp/kubeadm /usr/local/bin/kubeadm

curl -sL "${KUBELET_URL}" -o /tmp/kubelet
sudo install -o root -g root -m 0755 /tmp/kubelet /usr/local/bin/kubelet

curl -sL "${KUBECTL_URL}" -o /tmp/kubectl-eksd
sudo install -o root -g root -m 0755 /tmp/kubectl-eksd /usr/local/bin/kubectl

# Create kubelet systemd service
sudo mkdir -p /etc/systemd/system/kubelet.service.d

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# =============================================================================
# Step 4: AWS CLI already installed via dnf
# =============================================================================

echo "==> AWS CLI installed via dnf"

# =============================================================================
# Step 5: Pre-pull container images
# =============================================================================

echo "==> Pre-pulling container images..."
sudo ctr images pull registry.k8s.io/kube-proxy:v1.29.0 || true
sudo ctr images pull registry.k8s.io/coredns/coredns:v1.29.0 || true
sudo ctr images pull registry.k8s.io/pause:3.9 || true
sudo ctr images pull public.ecr.aws/karpenter/controller:v1.10.0 || true

# =============================================================================
# Step 6: Download CNI and CSI manifests
# =============================================================================

echo "==> Downloading CNI and CSI manifests..."
sudo mkdir -p /opt/eks-d/manifests

curl -sL "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml" \
  -o /opt/eks-d/manifests/aws-vpc-cni.yaml

curl -sL "https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/main/deploy/kubernetes/base/crds/csidriver.yaml" \
  -o /opt/eks-d/manifests/ebs-csi-driver.yaml || true

# =============================================================================
# Cleanup
# =============================================================================

echo "==> Cleaning up..."
rm -rf /tmp/*.tar.gz /tmp/eks-d-release.yaml /tmp/kubeadm /tmp/kubelet /tmp/kubectl-eksd

echo "==> AMI build complete!"
echo "    EKS-D version: ${EKSD_VERSION}-${EKSD_RELEASE}"
echo "    Karpenter: v1.10.0"
echo "    Binaries: /usr/local/bin/{kubeadm,kubelet,kubectl,helm,eksctl}"
echo "    Manifests: /opt/eks-d/manifests/"
