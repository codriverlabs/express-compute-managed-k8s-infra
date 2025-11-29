#!/bin/bash

# Update system
apt-get update
apt-get install -y curl wget unzip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Format and mount etcd volume
mkfs.ext4 /dev/nvme1n1
mkdir -p /var/lib/etcd
mount /dev/nvme1n1 /var/lib/etcd
echo '/dev/nvme1n1 /var/lib/etcd ext4 defaults 0 2' >> /etc/fstab

# Create setup directory
mkdir -p /home/ubuntu/eks-d-setup
chown ubuntu:ubuntu /home/ubuntu/eks-d-setup

# Create cluster info file
cat > /home/ubuntu/cluster-info.txt << EOF
Cluster Name: ${cluster_name}
Control Plane Instance: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EOF

chown ubuntu:ubuntu /home/ubuntu/cluster-info.txt
