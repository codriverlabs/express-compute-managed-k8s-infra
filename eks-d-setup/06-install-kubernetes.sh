#!/bin/bash
set -e

echo "Adding Kubernetes repository..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
EOF

echo "Installing kubeadm, kubelet, kubectl..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo "Enabling kubelet..."
sudo systemctl enable kubelet

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Initializing Kubernetes cluster..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=${PRIVATE_IP}

echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "✓ Kubernetes installed"
kubectl get nodes
