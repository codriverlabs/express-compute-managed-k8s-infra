#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sanitise() { echo "$1" | tr '@' '-' | tr -cs 'a-zA-Z0-9-' '-' | sed 's/-*$//'; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-D Workstation — Destroy                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

DEVELOPER_USERNAME="${DEVELOPER_USERNAME:-}"
if [ -z "$DEVELOPER_USERNAME" ]; then
  read -rp "  Developer IAM username: " DEVELOPER_USERNAME
  [ -z "${DEVELOPER_USERNAME}" ] && { echo "ERROR: username required" >&2; exit 1; }
fi

AWS_REGION="${AWS_REGION:-}"
if [ -z "$AWS_REGION" ]; then
  read -rp "  AWS region [us-east-1]: " input
  AWS_REGION="${input:-us-east-1}"
fi

echo "  Architecture:"
echo "    1) x86_64"
echo "    2) arm64"
read -rp "  Select [1]: " arch_choice
case "${arch_choice:-1}" in
  2) ARCH="arm64" ;;
  *) ARCH="x86_64" ;;
esac

TFSTATE_BUCKET="${TFSTATE_BUCKET:-}"
if [ -z "$TFSTATE_BUCKET" ]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  TFSTATE_BUCKET="eks-d-tfstate-${ACCOUNT_ID}"
  echo "  Auto-derived Terraform state bucket: ${TFSTATE_BUCKET}"
fi

SAFE_USER="$(sanitise "${DEVELOPER_USERNAME}")"
WORKSTATION_NAME="${SAFE_USER}-eks-d-${ARCH}"
TF_KEY="eks-d/${WORKSTATION_NAME}/terraform.tfstate"

echo ""
echo "  WARNING: This will permanently destroy workstation '${WORKSTATION_NAME}'."
read -rp "  Type 'yes' to confirm: " CONFIRM
[ "${CONFIRM}" != "yes" ] && { echo "Aborted."; exit 0; }

terraform -chdir="${SCRIPT_DIR}/terraform" init -reconfigure \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=${TF_KEY}" \
  -backend-config="region=${AWS_REGION}"

terraform -chdir="${SCRIPT_DIR}/terraform" destroy

echo "" && echo "==> Workstation '${WORKSTATION_NAME}' destroyed."
