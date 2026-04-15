#!/bin/bash
set -e

echo "Formatting etcd volume..."
sudo mkfs.ext4 /dev/nvme1n1

echo "Creating mount point..."
sudo mkdir -p /var/lib/etcd

echo "Mounting volume..."
sudo mount /dev/nvme1n1 /var/lib/etcd

echo "Removing lost+found..."
sudo rm -rf /var/lib/etcd/lost+found

echo "Adding to fstab..."
echo '/dev/nvme1n1 /var/lib/etcd ext4 defaults 0 2' | sudo tee -a /etc/fstab

echo "✓ etcd volume prepared"
df -h /var/lib/etcd
