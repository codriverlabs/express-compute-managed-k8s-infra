#!/bin/bash
set -e

# EKS-D version (must match 06-install-eks-d.sh)
EKSD_VERSION="${EKSD_VERSION:-1-33}"
EKSD_RELEASE="${EKSD_RELEASE:-19}"

echo "Configuring containerd for EKS-D..."

# Download release manifest if not already present
if [ ! -f /tmp/eks-d-release.yaml ]; then
  curl -sL "https://distro.eks.amazonaws.com/kubernetes-${EKSD_VERSION}/kubernetes-${EKSD_VERSION}-eks-${EKSD_RELEASE}.yaml" \
    -o /tmp/eks-d-release.yaml
fi

# Extract EKS-D pause image URI
PAUSE_IMAGE=$(grep "kubernetes/pause" /tmp/eks-d-release.yaml | grep "uri:" | head -1 | awk '{print $2}')
if [ -z "$PAUSE_IMAGE" ]; then
  echo "ERROR: Could not extract pause image from release manifest"
  exit 1
fi
echo "  pause image: ${PAUSE_IMAGE}"

# Generate default containerd config and apply EKS-D overrides
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

sudo sed -i "s|sandbox_image = .*|sandbox_image = \"${PAUSE_IMAGE}\"|" /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl is-active containerd

echo "✓ containerd configured (pause: ${PAUSE_IMAGE}, SystemdCgroup: true)"
