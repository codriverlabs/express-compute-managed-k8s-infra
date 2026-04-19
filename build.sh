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
echo "║   EKS-D Workstation — Build AMI              ║"
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

TFSTATE_BUCKET="${TFSTATE_BUCKET:-}"
if [ -z "${TFSTATE_BUCKET}" ]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  TFSTATE_BUCKET="eks-d-tfstate-${ACCOUNT_ID}"
  echo "  Auto-derived Terraform state bucket: ${TFSTATE_BUCKET}"
fi

KEY_NAME="eks-d-builder-${ARCH}-${AMI_VERSION}"
KEY_FILE="${SCRIPT_DIR}/${KEY_NAME}.pem"

echo ""
echo "==> Creating temporary EC2 key pair '${KEY_NAME}'..."
aws ec2 create-key-pair --key-name "${KEY_NAME}" --region "${AWS_REGION}" \
  --query 'KeyMaterial' --output text > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"

cleanup() {
  echo "" && echo "==> Cleaning up temporary key pair..."
  aws ec2 delete-key-pair --key-name "${KEY_NAME}" --region "${AWS_REGION}" 2>/dev/null || true
  rm -f "${KEY_FILE}"
}
trap cleanup EXIT

TF_KEY="eks-d/ami-builder/${ARCH}/terraform.tfstate"

echo "==> Initialising Terraform backend..."
terraform -chdir="${AMI_BUILDER_DIR}" init -reconfigure \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=${TF_KEY}" \
  -backend-config="region=${AWS_REGION}"

echo "" && echo "==> Building AMI (arch=${ARCH})... (~20-30 min)"
terraform -chdir="${AMI_BUILDER_DIR}" apply -auto-approve \
  -var "aws_region=${AWS_REGION}" \
  -var "arch=${ARCH}" \
  -var "instance_type=${INSTANCE_TYPE}" \
  -var "key_pair_name=${KEY_NAME}" \
  -var "key_file=${KEY_FILE}" \
  -var "ami_version=${AMI_VERSION}"

echo "" && echo "==> Destroying builder instance..."
terraform -chdir="${AMI_BUILDER_DIR}" destroy -auto-approve \
  -var "aws_region=${AWS_REGION}" \
  -var "arch=${ARCH}" \
  -var "instance_type=${INSTANCE_TYPE}" \
  -var "key_pair_name=${KEY_NAME}" \
  -var "key_file=${KEY_FILE}" \
  -var "ami_version=${AMI_VERSION}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   AMI build complete                         ║"
echo "╚══════════════════════════════════════════════╝"
echo "  AMI ID stored at SSM: /eks-d/ami/${ARCH}"
echo "  Run ./deploy.sh to launch a workstation."
