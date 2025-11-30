#!/bin/bash
set -e

echo "Installing Docker..."
sudo dnf install -y docker

echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

echo "✓ Docker installed"
echo "Note: Re-login or run 'newgrp docker' to use docker without sudo"
