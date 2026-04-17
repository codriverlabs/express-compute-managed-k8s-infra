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

# Load EKS-D version information (discovered during AMI build)
if [ -f "/opt/eks-d/manifests/eks-d-versions.env" ]; then
  source /opt/eks-d/manifests/eks-d-versions.env
  echo "Using discovered EKS-D ${EKSD_VERSION}-eks-${EKSD_RELEASE}"
else
  # Fallback to hardcoded values if discovery file not found
  echo "Warning: EKS-D discovery file not found, using fallback values"
  EKSD_VERSION="1-35"
  EKSD_RELEASE="8"
fi

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
AWS_REGION=$(curl -sf http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$(curl -sf http://169.254.169.254/latest/dynamic/instance-identity/document | python3 -c "import sys,json; print(json.load(sys.stdin)['accountId'])")

echo "  k8s tag:     ${EKSD_K8S_TAG}"
echo "  etcd tag:    ${EKSD_ETCD_TAG}"
echo "  coredns tag: ${EKSD_COREDNS_TAG}"
echo "  node IP:     ${PRIVATE_IP}"

# --- aws-iam-authenticator setup (must happen before kubeadm init) ---
# This enables EKS-Optimized AL2023 worker nodes to authenticate via IAM role.
echo "Configuring aws-iam-authenticator..."
source /opt/eks-d/manifests/eks-d-versions.env
AUTH_IMAGE="${AWS_IAM_AUTHENTICATOR_IMAGE}"

sudo mkdir -p /etc/kubernetes/aws-iam-authenticator

# Authenticator config: map the workstation IAM role to system:nodes
# The role name pattern matches eks-d-workstation-<signum>
cat <<AUTHEOF | sudo tee /etc/kubernetes/aws-iam-authenticator/config.yaml
clusterID: ${CLUSTER_NAME:-eks-d}
server:
  mapRoles:
    # Worker nodes launched by Karpenter use the workstation role
    - roleARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-d-workstation-*
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
AUTHEOF

# Webhook kubeconfig for the API server to call the authenticator
cat <<WEBHOOKEOF | sudo tee /etc/kubernetes/aws-iam-authenticator/kubeconfig.yaml
apiVersion: v1
kind: Config
clusters:
  - name: aws-iam-authenticator
    cluster:
      server: https://localhost:21362/authenticate
      insecure-skip-tls-verify: true
users:
  - name: kube-apiserver
contexts:
  - name: aws-iam-authenticator
    context:
      cluster: aws-iam-authenticator
      user: kube-apiserver
current-context: aws-iam-authenticator
WEBHOOKEOF

# Static pod manifest for the authenticator
cat <<PODEOF | sudo tee /etc/kubernetes/manifests/aws-iam-authenticator.yaml
apiVersion: v1
kind: Pod
metadata:
  name: aws-iam-authenticator
  namespace: kube-system
  labels:
    app: aws-iam-authenticator
spec:
  hostNetwork: true
  containers:
    - name: aws-iam-authenticator
      image: ${AUTH_IMAGE}
      args:
        - server
        - --config=/etc/aws-iam-authenticator/config.yaml
        - --state-dir=/var/aws-iam-authenticator
        - --generate-kubeconfig=/etc/aws-iam-authenticator/kubeconfig.yaml
        - --kubeconfig-pregenerated=true
      volumeMounts:
        - name: config
          mountPath: /etc/aws-iam-authenticator
        - name: state
          mountPath: /var/aws-iam-authenticator
  volumes:
    - name: config
      hostPath:
        path: /etc/kubernetes/aws-iam-authenticator
    - name: state
      hostPath:
        path: /var/aws-iam-authenticator
        type: DirectoryOrCreate
PODEOF

echo "✓ aws-iam-authenticator configured"
# --- end aws-iam-authenticator setup ---

cat <<EOF | sudo tee /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
imageRepository: public.ecr.aws/eks-distro/kubernetes
kubernetesVersion: ${EKSD_K8S_TAG}
controlPlaneEndpoint: ${PRIVATE_IP}
networking:
  serviceSubnet: 10.96.0.0/12
dns:
  imageRepository: public.ecr.aws/eks-distro/coredns
  imageTag: ${EKSD_COREDNS_TAG}
etcd:
  local:
    imageRepository: public.ecr.aws/eks-distro/etcd-io
    imageTag: ${EKSD_ETCD_TAG}
apiServer:
  extraArgs:
    authentication-token-webhook-config-file: /etc/kubernetes/aws-iam-authenticator/kubeconfig.yaml
  extraVolumes:
    - name: aws-iam-authenticator
      hostPath: /etc/kubernetes/aws-iam-authenticator
      mountPath: /etc/kubernetes/aws-iam-authenticator
      readOnly: true
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
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
