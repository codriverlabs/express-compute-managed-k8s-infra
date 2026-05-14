#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMI_BUILDER_DIR="${SCRIPT_DIR}/ami-builder"
AMI_VERSION=$(date +%Y%m%d-%H%M)

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
