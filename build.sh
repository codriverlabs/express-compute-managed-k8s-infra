#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMI_BUILDER_DIR="${SCRIPT_DIR}/ami-builder"
AMI_VERSION=$(date +%Y%m%d-%H%M)

ensure_packer() {
  if command -v packer &>/dev/null; then return; fi
  echo "==> packer not found, installing..."
  local version
  version=$(grep '^packer ' "$(dirname "$0")/.tool-versions" | awk '{print $2}')
  local arch; arch=$(uname -m)
  [ "${arch}" = "aarch64" ] && arch="arm64" || arch="amd64"
  local os; os=$(uname -s | tr '[:upper:]' '[:lower:]')
  local url="https://releases.hashicorp.com/packer/${version}/packer_${version}_${os}_${arch}.zip"
  curl -fsSL "${url}" -o /tmp/packer.zip
  unzip -o /tmp/packer.zip -d /tmp
  sudo mv /tmp/packer /usr/local/bin/packer
  rm /tmp/packer.zip
  echo "    ✓ packer ${version} installed"
}

ensure_packer

prompt() {
  local var="$1" msg="$2" default="$3"
  local current="${!var:-}"
  if [ -n "$current" ]; then echo "    ${msg} [${current}]: using env value"; return; fi
  read -rp "  ${msg} [${default}]: " input
  printf -v "$var" '%s' "${input:-$default}"
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Workstation — Build AMI             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

AWS_REGION="${AWS_REGION:-}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-}"
prompt AWS_REGION         "AWS region"          "us-east-1"
prompt KUBERNETES_VERSION "Kubernetes version"  "1.35"

echo "" && echo "==> Building x86_64 + arm64 in parallel (arch=${ARCH:-both})... (~20-30 min)"

packer init "${AMI_BUILDER_DIR}/eks-dx.pkr.hcl"

packer build \
  -var "aws_region=${AWS_REGION}" \
  -var "kubernetes_version=${KUBERNETES_VERSION}" \
  -var "ami_version=${AMI_VERSION}" \
  "${AMI_BUILDER_DIR}/eks-dx.pkr.hcl"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   AMI build complete                         ║"
echo "╚══════════════════════════════════════════════╝"
echo "  AMI IDs stored at SSM:"
echo "    /eks-dx/ami/${KUBERNETES_VERSION}/x86_64"
echo "    /eks-dx/ami/${KUBERNETES_VERSION}/arm64"
echo "  Run ./deploy.sh to launch a workstation."
