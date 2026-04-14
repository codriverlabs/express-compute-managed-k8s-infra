#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected architecture: $ARCH"

# EKS-D version matching Kubernetes 1.33
EKSD_VERSION="1-33"
EKSD_RELEASE="19"

echo "Installing EKS-D (EKS Distro) ${EKSD_VERSION} for ${ARCH}..."

# Download EKS-D release manifest
echo "Downloading EKS-D release manifest..."
curl -sL "https://distro.eks.amazonaws.com/kubernetes-${EKSD_VERSION}/kubernetes-${EKSD_VERSION}-eks-${EKSD_RELEASE}.yaml" -o /tmp/eks-d-release.yaml

# Extract component URLs for the detected architecture
echo "Extracting ${ARCH} binaries..."
KUBEADM_URL=$(grep "bin/linux/${ARCH}/kubeadm" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBELET_URL=$(grep "bin/linux/${ARCH}/kubelet" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBECTL_URL=$(grep "bin/linux/${ARCH}/kubectl" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')

echo "Downloading EKS-D binaries..."
echo "  kubeadm: ${KUBEADM_URL}"
echo "  kubelet: ${KUBELET_URL}"
echo "  kubectl: ${KUBECTL_URL}"

# Download and install kubeadm
curl -sL "${KUBEADM_URL}" -o /tmp/kubeadm
sudo install -o root -g root -m 0755 /tmp/kubeadm /usr/local/bin/kubeadm

# Download and install kubelet
curl -sL "${KUBELET_URL}" -o /tmp/kubelet
sudo install -o root -g root -m 0755 /tmp/kubelet /usr/local/bin/kubelet

# Download and install kubectl (EKS-D version)
curl -sL "${KUBECTL_URL}" -o /tmp/kubectl
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# Create kubelet systemd service
echo "Creating kubelet systemd service..."
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

echo "Enabling kubelet..."
sudo systemctl daemon-reload
sudo systemctl enable kubelet

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# If AMI_BUILD, skip kubeadm init (will run on first boot)
if [ "${AMI_BUILD:-}" = "true" ]; then
  echo "⏭ Skipping kubeadm init (AMI build - will run on first boot)"
  rm -f /tmp/eks-d-release.yaml /tmp/kubeadm /tmp/kubelet /tmp/kubectl
  echo "✓ EKS-D binaries installed"
  exit 0
fi

echo "Initializing EKS-D cluster..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=${PRIVATE_IP}

echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Cleanup
rm -f /tmp/eks-d-release.yaml /tmp/kubeadm /tmp/kubelet /tmp/kubectl

echo "✓ EKS-D installed"
kubectl version
kubectl get nodes
