#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
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
curl -sL "https://distro.eks.amazonaws.com/kubernetes-${EKSD_VERSION}/kubernetes-${EKSD_VERSION}-eks-${EKSD_RELEASE}.yaml" \
  -o /tmp/eks-d-release.yaml

# Extract component URLs for the detected architecture
echo "Extracting ${ARCH} binaries..."
KUBEADM_URL=$(grep "bin/linux/${ARCH}/kubeadm" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBELET_URL=$(grep "bin/linux/${ARCH}/kubelet" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')
KUBECTL_URL=$(grep "bin/linux/${ARCH}/kubectl" /tmp/eks-d-release.yaml -B 1 | grep "uri:" | awk '{print $2}')

echo "Downloading EKS-D binaries..."
curl -sL "${KUBEADM_URL}" -o /tmp/kubeadm
sudo install -o root -g root -m 0755 /tmp/kubeadm /usr/local/bin/kubeadm

curl -sL "${KUBELET_URL}" -o /tmp/kubelet
sudo install -o root -g root -m 0755 /tmp/kubelet /usr/local/bin/kubelet

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

echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "Starting containerd..."
sudo systemctl enable containerd
sudo systemctl start containerd

# Install ECR credential provider (needed before kubeadm init so it can be in the config)
echo "Installing ECR credential provider..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp "${SCRIPT_DIR}/${ARCH}/ecr-credential-provider" /usr/bin/ecr-credential-provider
sudo chmod +x /usr/bin/ecr-credential-provider

sudo mkdir -p /etc/kubernetes/credential-provider
sudo tee /etc/kubernetes/credential-provider/config.yaml <<EOFCRED
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    matchImages:
      - "*.dkr.ecr.*.amazonaws.com"
      - "*.dkr.ecr.*.amazonaws.com.cn"
      - "*.dkr.ecr-fips.*.amazonaws.com"
      - "public.ecr.aws"
    defaultCacheDuration: 12h
    apiVersion: credentialprovider.kubelet.k8s.io/v1
EOFCRED

echo "✓ ECR credential provider installed"

# If AMI_BUILD, skip kubeadm init (will run on first boot)
if [ "${AMI_BUILD:-}" = "true" ]; then
  echo "⏭ Skipping kubeadm init (AMI build - will run on first boot)"
  rm -f /tmp/kubeadm /tmp/kubelet /tmp/kubectl
  echo "✓ EKS-D binaries installed"
  exit 0
fi

echo "Initializing EKS-D cluster..."

# Extract image tags from the EKS-D release manifest
EKSD_K8S_TAG=$(grep "kubernetes/kube-apiserver" /tmp/eks-d-release.yaml | grep "uri:" | head -1 | sed 's/.*://')
EKSD_ETCD_TAG=$(grep "etcd-io/etcd" /tmp/eks-d-release.yaml | grep "uri:" | head -1 | sed 's/.*://')
EKSD_COREDNS_TAG=$(grep "coredns/coredns" /tmp/eks-d-release.yaml | grep "uri:" | head -1 | sed 's/.*://')
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo "  k8s tag:     ${EKSD_K8S_TAG}"
echo "  etcd tag:    ${EKSD_ETCD_TAG}"
echo "  coredns tag: ${EKSD_COREDNS_TAG}"
echo "  node IP:     ${PRIVATE_IP}"

cat <<EOF | sudo tee /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
imageRepository: public.ecr.aws/eks-distro/kubernetes
kubernetesVersion: ${EKSD_K8S_TAG}
controlPlaneEndpoint: ${PRIVATE_IP}
networking:
  serviceSubnet: 10.96.0.0/12
apiServer:
  extraArgs:
    cloud-provider: external
controllerManager:
  extraArgs:
    cloud-provider: external
dns:
  imageRepository: public.ecr.aws/eks-distro/coredns
  imageTag: ${EKSD_COREDNS_TAG}
etcd:
  local:
    imageRepository: public.ecr.aws/eks-distro/etcd-io
    imageTag: ${EKSD_ETCD_TAG}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: external
    image-credential-provider-config: /etc/kubernetes/credential-provider/config.yaml
    image-credential-provider-bin-dir: /usr/bin
EOF

sudo kubeadm init \
  --config /tmp/kubeadm-config.yaml \
  --ignore-preflight-errors=NumCPU,DirAvailable--var-lib-etcd

echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Cleanup
rm -f /tmp/eks-d-release.yaml /tmp/kubeadm /tmp/kubelet /tmp/kubectl /tmp/kubeadm-config.yaml

echo "✓ EKS-D installed"
kubectl version
kubectl get nodes
