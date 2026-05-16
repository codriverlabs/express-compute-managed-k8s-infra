#!/bin/bash
set -e

# EKS-D AMI Installation Script
# Pre-installs binaries, images, and scripts for fast workstation boot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EKS_D_SETUP_DIR="/tmp/eks-d-setup"

# EKS-D version discovery (configurable)
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.35}"

# Get EKS versions from VPC tags or use defaults
EKS_VERSION=$(aws ec2 describe-vpcs --filters "Name=tag:EKSVersion,Values=*" \
  --query 'Vpcs[0].Tags[?Key==`EKSVersion`].Value' --output text 2>/dev/null || echo "$KUBERNETES_VERSION")
EKSD_VERSION=$(aws ec2 describe-vpcs --filters "Name=tag:EKSDVersion,Values=*" \
  --query 'Vpcs[0].Tags[?Key==`EKSDVersion`].Value' --output text 2>/dev/null || echo "${KUBERNETES_VERSION}.8")

echo "==> Discovering EKS-D components for Kubernetes ${EKS_VERSION} / EKS-D ${EKSD_VERSION}..."

# Store configuration for later use
sudo mkdir -p /opt/eks-d
echo "EKS_VERSION=$EKS_VERSION" | sudo tee /opt/eks-d/version.env
echo "EKSD_VERSION=$EKSD_VERSION" | sudo tee -a /opt/eks-d/version.env
echo "TAGGED_AMIS=eks-dx-$EKS_VERSION" | sudo tee -a /opt/eks-d/version.env

bash "${SCRIPT_DIR}/discover-eks-d.sh" "$EKS_VERSION" "/opt/eks-d/manifests"

# Load discovered versions
source /opt/eks-d/manifests/eks-d-versions.env
echo "==> Using EKS-D ${EKSD_VERSION}-eks-${EKSD_RELEASE}"

export AMI_BUILD=true

# Set up ECR pull-through cache for public.ecr.aws
echo "==> Configuring ECR pull-through cache..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(curl -sf http://169.254.169.254/latest/meta-data/placement/region)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
PUBLIC_ECR_CACHE="${ECR_REGISTRY}/public-ecr"

# Authenticate containerd with ECR
aws ecr get-login-password --region "${REGION}" | \
  sudo ctr images login --username AWS --password-stdin "${ECR_REGISTRY}"

# Authenticate helm with ECR
aws ecr get-login-password --region "${REGION}" | \
  helm registry login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "    ✓ ECR registry: ${ECR_REGISTRY}"

echo "==> Installing base system..."
bash "${EKS_D_SETUP_DIR}/01-install-base.sh"

echo "==> Installing Docker..."
bash "${EKS_D_SETUP_DIR}/02-install-docker.sh"

echo "==> Installing Helm..."
bash "${EKS_D_SETUP_DIR}/04-install-helm.sh"

echo "==> Installing EKS-D binaries..."
bash "${EKS_D_SETUP_DIR}/06-install-eks-d.sh"

# Configure containerd with EKS-D pause image (release manifest already downloaded by 06)
echo "==> Configuring containerd..."
bash "${EKS_D_SETUP_DIR}/00-configure-containerd.sh"

# Copy eks-d-setup scripts to AMI for use at boot time
echo "==> Installing eks-d-setup scripts..."
sudo mkdir -p /opt/eks-d-setup
sudo cp -r "${EKS_D_SETUP_DIR}"/* /opt/eks-d-setup/
sudo chmod +x /opt/eks-d-setup/*.sh

# Pre-download Helm charts and manifests FIRST (needed for image discovery)
echo "==> Pre-pulling Karpenter chart from OCI registry..."
helm registry logout public.ecr.aws 2>/dev/null || true
helm pull oci://${PUBLIC_ECR_CACHE}/karpenter/karpenter --version "1.10.0" --destination /tmp || true
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm pull aws-cloud-controller-manager/aws-cloud-controller-manager --destination /tmp || true
helm pull aws-ebs-csi-driver/aws-ebs-csi-driver --destination /tmp || true
sudo mkdir -p /opt/eks-d/charts
sudo mv /tmp/karpenter-*.tgz /opt/eks-d/charts/ 2>/dev/null || true
sudo mv /tmp/aws-cloud-controller-manager-*.tgz /opt/eks-d/charts/ 2>/dev/null || true
sudo mv /tmp/aws-ebs-csi-driver-*.tgz /opt/eks-d/charts/ 2>/dev/null || true

echo "==> Pre-pulling CloudWatch Observability Helm chart..."
helm repo add aws-observability https://aws-observability.github.io/helm-charts 2>/dev/null || true
helm repo update
helm pull aws-observability/amazon-cloudwatch-observability --destination /tmp || true
sudo mv /tmp/amazon-cloudwatch-observability-*.tgz /opt/eks-d/charts/ 2>/dev/null || true

echo "==> Pre-downloading manifests..."
sudo mkdir -p /opt/eks-d/manifests
sudo curl -sL "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml" \
  -o /opt/eks-d/manifests/aws-vpc-cni.yaml
# Note: CoreDNS is installed automatically by kubeadm init — no separate manifest needed

# Pre-pull container images by inspecting charts and manifests
echo "==> Discovering and pre-pulling container images..."
sudo systemctl start containerd

# Pull EKS-D control plane images directly from the downloaded manifest
echo "==> Pulling EKS-D control plane images..."
grep "uri: public.ecr.aws/eks-distro/kubernetes/" /opt/eks-d/manifests/eks-d-release.yaml | awk '{print $2}' | sort -u | while read img; do
  cache_img="${PUBLIC_ECR_CACHE}/${img#public.ecr.aws/}"
  echo "  Pulling: $cache_img"
  sudo ctr images pull "$cache_img" || true
done
grep "uri: public.ecr.aws/eks-distro/etcd-io/" /opt/eks-d/manifests/eks-d-release.yaml | awk '{print $2}' | sort -u | while read img; do
  cache_img="${PUBLIC_ECR_CACHE}/${img#public.ecr.aws/}"
  echo "  Pulling: $cache_img"
  sudo ctr images pull "$cache_img" || true
done
grep "uri: public.ecr.aws/eks-distro/coredns/" /opt/eks-d/manifests/eks-d-release.yaml | awk '{print $2}' | sort -u | while read img; do
  cache_img="${PUBLIC_ECR_CACHE}/${img#public.ecr.aws/}"
  echo "  Pulling: $cache_img"
  sudo ctr images pull "$cache_img" || true
done

# Render Karpenter chart and extract images
echo "==> Extracting and pulling images from Karpenter chart..."
KARPENTER_CHART=$(ls /opt/eks-d/charts/karpenter-*.tgz 2>/dev/null | head -1)
if [ -n "$KARPENTER_CHART" ]; then
  helm template karpenter "$KARPENTER_CHART" 2>/dev/null | \
    grep -oP 'image:\s*\K[^\s]+' | sort -u | while read img; do
      cache_img=$(echo "$img" | sed "s|public.ecr.aws/|${PUBLIC_ECR_CACHE}/|")
      echo "  Pulling: $cache_img"
      sudo ctr images pull "$cache_img" || true
    done
fi

# Render cloud-provider-aws chart and extract images
echo "==> Extracting and pulling images from cloud-provider-aws chart..."
CLOUD_PROVIDER_CHART=$(ls /opt/eks-d/charts/aws-cloud-controller-manager-*.tgz 2>/dev/null | head -1)
if [ -n "$CLOUD_PROVIDER_CHART" ]; then
  helm template aws-cloud-controller-manager "$CLOUD_PROVIDER_CHART" 2>/dev/null | \
    grep -oP 'image:\s*\K[^\s]+' | sort -u | while read img; do
      cache_img=$(echo "$img" | sed "s|public.ecr.aws/|${PUBLIC_ECR_CACHE}/|")
      echo "  Pulling: $cache_img"
      sudo ctr images pull "$cache_img" || true
    done
fi

# Render EBS CSI chart and extract images
echo "==> Extracting and pulling images from EBS CSI chart..."
EBS_CSI_CHART=$(ls /opt/eks-d/charts/aws-ebs-csi-driver-*.tgz 2>/dev/null | head -1)
if [ -n "$EBS_CSI_CHART" ]; then
  helm template aws-ebs-csi-driver "$EBS_CSI_CHART" 2>/dev/null | \
    grep -oP 'image:\s*\K[^\s]+' | sort -u | while read img; do
      cache_img=$(echo "$img" | sed "s|public.ecr.aws/|${PUBLIC_ECR_CACHE}/|")
      echo "  Pulling: $cache_img"
      sudo ctr images pull "$cache_img" || true
    done
fi

# Extract images from VPC CNI manifest
echo "==> Extracting and pulling images from VPC CNI manifest..."
if [ -f /opt/eks-d/manifests/aws-vpc-cni.yaml ]; then
  grep -oP 'image:\s*\K[^\s]+' /opt/eks-d/manifests/aws-vpc-cni.yaml | sort -u | while read img; do
    echo "  Pulling: $img"
    sudo ctr images pull "$img" || true
  done
fi

# EBS CSI driver images are extracted and pulled from the chart above

# Pull CSI sidecar images using discovered versions
if [ -n "$CSI_PROVISIONER_IMAGE" ]; then
  sudo ctr images pull "$CSI_PROVISIONER_IMAGE" || true
fi
if [ -n "$CSI_ATTACHER_IMAGE" ]; then
  sudo ctr images pull "$CSI_ATTACHER_IMAGE" || true
fi
if [ -n "$LIVENESSPROBE_IMAGE" ]; then
  sudo ctr images pull "$LIVENESSPROBE_IMAGE" || true
fi
if [ -n "$CSI_RESIZER_IMAGE" ]; then
  sudo ctr images pull "$CSI_RESIZER_IMAGE" || true
fi

# Metrics Server
if [ -n "$METRICS_SERVER_IMAGE" ]; then
  echo "==> Pulling Metrics Server image..."
  sudo ctr images pull "$METRICS_SERVER_IMAGE" || true
fi

# aws-iam-authenticator — runs as static pod for worker node IAM auth
echo "==> Pulling aws-iam-authenticator image..."
if [ -n "$AWS_IAM_AUTHENTICATOR_IMAGE" ]; then
  sudo ctr images pull "$AWS_IAM_AUTHENTICATOR_IMAGE" || true
fi

# Render CloudWatch Observability chart and extract images
echo "==> Extracting and pulling images from CloudWatch Observability chart..."
CW_CHART=$(ls /opt/eks-d/charts/amazon-cloudwatch-observability-*.tgz 2>/dev/null | head -1)
if [ -n "$CW_CHART" ]; then
  helm template amazon-cloudwatch-observability "$CW_CHART" \
    --set clusterName=build --set region=us-east-1 2>/dev/null | \
    grep -oP 'image:\s*\K[^\s]+' | sort -u | while read img; do
      cache_img=$(echo "$img" | sed "s|public.ecr.aws/|${PUBLIC_ECR_CACHE}/|")
      echo "  Pulling: $cache_img"
      sudo ctr images pull "$cache_img" || true
    done
fi

echo ""
echo "==> AMI build complete!"
echo "    Scripts installed to /opt/eks-d-setup/"
echo "    Charts installed to /opt/eks-d/charts/"
echo "    Manifests installed to /opt/eks-d/manifests/"
echo "    All images pre-pulled for fast boot."
