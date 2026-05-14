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
prompt AWS_REGION "AWS region" "us-east-1"

echo ""
echo "  Architecture:"
echo "    1) x86_64  (Intel/AMD)"
echo "    2) arm64   (Graviton)"
read -rp "  Select [1]: " arch_choice
case "${arch_choice:-1}" in
  2) ARCH="arm64"; INSTANCE_TYPE="t4g.large" ;;
  *) ARCH="x86_64"; INSTANCE_TYPE="m6i.xlarge" ;;
esac

echo "" && echo "==> Initialising Packer plugins..."
packer init "${AMI_BUILDER_DIR}/eks-dx.pkr.hcl"

echo "" && echo "==> Building AMI (arch=${ARCH})... (~20-30 min)"
packer build \
  -var "aws_region=${AWS_REGION}" \
  -var "arch=${ARCH}" \
  -var "instance_type=${INSTANCE_TYPE}" \
  -var "kubernetes_version=${KUBERNETES_VERSION:-1.35}" \
  -var "ami_version=${AMI_VERSION}" \
  "${AMI_BUILDER_DIR}/eks-dx.pkr.hcl"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   AMI build complete                         ║"
echo "╚══════════════════════════════════════════════╝"
echo "  AMI ID stored at SSM: /eks-dx/ami/${ARCH}"
echo "  Run ./deploy.sh to launch a workstation."
