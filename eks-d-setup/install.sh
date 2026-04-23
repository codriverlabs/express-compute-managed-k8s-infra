#!/bin/bash

set -e

# Configuration
EKS_D_VERSION="v1.28.2-eks-1-28-6"
CLUSTER_NAME=${1:-$(hostname)-eks-dx}
CONTROL_PLANE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Installing EKS-D ${EKS_D_VERSION} for cluster: ${CLUSTER_NAME}"

# Create directories
sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /var/lib/etcd

# Download EKS-D binaries
cd /tmp
wget https://distro.eks.amazonaws.com/kubernetes-${EKS_D_VERSION}/releases/1/artifacts/kubernetes/v1.28.2/bin/linux/amd64/kubeadm
wget https://distro.eks.amazonaws.com/kubernetes-${EKS_D_VERSION}/releases/1/artifacts/kubernetes/v1.28.2/bin/linux/amd64/kubelet
wget https://distro.eks.amazonaws.com/kubernetes-${EKS_D_VERSION}/releases/1/artifacts/kubernetes/v1.28.2/bin/linux/amd64/kubectl

# Install binaries
chmod +x kubeadm kubelet kubectl
sudo mv kubeadm kubelet kubectl /usr/local/bin/

# Create kubeadm config
cat > /tmp/kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_PLANE_IP}
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
clusterName: ${CLUSTER_NAME}
kubernetesVersion: v1.28.2
controlPlaneEndpoint: ${PUBLIC_IP}:6443
apiServer:
  extraArgs:
    cloud-provider: aws
  certSANs:
  - ${PUBLIC_IP}
  - ${CONTROL_PLANE_IP}
controllerManager:
  extraArgs:
    cloud-provider: aws
etcd:
  local:
    dataDir: /var/lib/etcd
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 192.168.0.0/16
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cloudProvider: aws
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: iptables
EOF

# Initialize cluster
sudo kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs

# Setup kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Install CNI (AWS VPC CNI)
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.15.1/config/master/aws-k8s-cni.yaml

# Remove taint from control plane to allow scheduling (single node setup)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Create cluster info
cat > /home/ubuntu/cluster-ready.txt << EOF
EKS-D Cluster Ready!

Cluster Name: ${CLUSTER_NAME}
API Endpoint: https://${PUBLIC_IP}:6443
Kubeconfig: /home/ubuntu/.kube/config

Next steps:
1. Install Karpenter: cd ../karpenter-config && ./install-karpenter.sh
2. Create NodePools: cd ../node-pools && kubectl apply -f spot-nodepool.yaml

Test cluster:
kubectl get nodes
kubectl get pods -A
EOF

echo "EKS-D installation complete!"
echo "Cluster info saved to /home/ubuntu/cluster-ready.txt"
