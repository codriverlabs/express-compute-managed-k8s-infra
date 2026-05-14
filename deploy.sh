#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt() {
  local var="$1" msg="$2" default="$3"
  local current="${!var:-}"
  if [ -n "$current" ]; then echo "    ${msg} [${current}]: using env value"; return; fi
  read -rp "  ${msg} [${default}]: " input
  printf -v "$var" '%s' "${input:-$default}"
}

sanitise() { echo "$1" | tr '@' '-' | tr -cs 'a-zA-Z0-9-' '-' | sed 's/-*$//'; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Workstation — Deploy                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

DEVELOPER_USERNAME="${DEVELOPER_USERNAME:-}"
prompt DEVELOPER_USERNAME "Developer IAM username" ""
if [ -z "${DEVELOPER_USERNAME}" ]; then
  echo "ERROR: developer IAM username is required." >&2; exit 1
fi

AWS_REGION="${AWS_REGION:-}"
prompt AWS_REGION "AWS region" "us-east-1"

ARCH="${ARCH:-}"
if [ -z "$ARCH" ]; then
  echo ""
  echo "  Architecture:"
  echo "    1) x86_64  (Intel/AMD)"
  echo "    2) arm64   (Graviton)"
  read -rp "  Select [1]: " arch_choice
  case "${arch_choice:-1}" in
    2) ARCH="arm64" ;;
    *) ARCH="x86_64" ;;
  esac
fi

case "$ARCH" in
  arm64) INSTANCE_TYPE="m6g.large" ;;
  x86_64) INSTANCE_TYPE="m6i.xlarge" ;;
  *) echo "ERROR: Invalid ARCH '$ARCH'. Use 'x86_64' or 'arm64'." >&2; exit 1 ;;
esac

DISK_SIZE_GB="${DISK_SIZE_GB:-}"
prompt DISK_SIZE_GB "Root disk size (GB)" "50"

KUBERNETES_VERSION="${KUBERNETES_VERSION:-}"
prompt KUBERNETES_VERSION "Kubernetes version" "1.35"
if [ -z "$ELASTIC_IP" ]; then
  read -rp "  Assign Elastic IP (stable IP across stop/start)? [y/N]: " eip_choice
  case "${eip_choice}" in
    [yY]*) ELASTIC_IP="true" ;;
    *) ELASTIC_IP="false" ;;
  esac
fi

SAFE_USER="$(sanitise "${DEVELOPER_USERNAME}")"
WORKSTATION_NAME="${SAFE_USER}-eks-dx-${ARCH}"
KEY_PAIR_NAME="${WORKSTATION_NAME}"
KEY_FILE="${SCRIPT_DIR}/${KEY_PAIR_NAME}.pem"

if aws ec2 describe-key-pairs --key-names "${KEY_PAIR_NAME}" --region "${AWS_REGION}" \
     --query 'KeyPairs[0].KeyName' --output text 2>/dev/null | grep -q "${KEY_PAIR_NAME}"; then
  echo "  Key pair '${KEY_PAIR_NAME}' already exists."
else
  echo "==> Creating EC2 key pair '${KEY_PAIR_NAME}'..."
  aws ec2 create-key-pair --key-name "${KEY_PAIR_NAME}" --region "${AWS_REGION}" \
    --query 'KeyMaterial' --output text > "${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
  echo "  Private key saved: ${KEY_FILE}"
fi

TFSTATE_BUCKET="${TFSTATE_BUCKET:-}"
if [ -z "${TFSTATE_BUCKET}" ]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  TFSTATE_BUCKET="eks-dx-tfstate-${ACCOUNT_ID}"
  echo "  Auto-derived Terraform state bucket: ${TFSTATE_BUCKET}"
fi

if [ -z "${SSH_CIDR:-}" ]; then
  MY_IP="$(curl -sf https://checkip.amazonaws.com/ || true)"
  if [ -z "$MY_IP" ]; then
    echo "ERROR: Could not detect public IP. Set SSH_CIDR=x.x.x.x/32 and retry." >&2; exit 1
  fi
  SSH_CIDR="${MY_IP}/32"
fi
prompt SSH_CIDR "SSH allowed CIDR" "${SSH_CIDR}"

TFVARS="${SCRIPT_DIR}/terraform/terraform.tfvars"
cat > "${TFVARS}" <<EOF
developer_username  = "${DEVELOPER_USERNAME}"
workstation_name    = "${WORKSTATION_NAME}"
aws_region          = "${AWS_REGION}"
arch                = "${ARCH}"
instance_type       = "${INSTANCE_TYPE}"
disk_size_gb        = ${DISK_SIZE_GB}
key_pair_name       = "${KEY_PAIR_NAME}"
allowed_cidr_blocks = ["${SSH_CIDR}"]
assign_elastic_ip   = ${ELASTIC_IP}
kubernetes_version  = "${KUBERNETES_VERSION}"
EOF

echo "" && echo "==> Written: terraform/terraform.tfvars"

TF_KEY="eks-dx/${WORKSTATION_NAME}/terraform.tfstate"

echo "" && echo "==> Initialising Terraform backend..."
terraform -chdir="${SCRIPT_DIR}/terraform" init -reconfigure \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=${TF_KEY}" \
  -backend-config="region=${AWS_REGION}"

echo "" && echo "==> Applying..."
if [ "${DRY_RUN:-}" = "true" ]; then
  terraform -chdir="${SCRIPT_DIR}/terraform" plan
  echo "" && echo "==> Dry run complete. Set DRY_RUN= to apply."
  exit 0
fi
terraform -chdir="${SCRIPT_DIR}/terraform" apply

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Workstation ready                          ║"
echo "╚══════════════════════════════════════════════╝"
PUBLIC_IP=$(terraform -chdir="${SCRIPT_DIR}/terraform" output -raw workstation_public_ip 2>/dev/null || echo "")

echo "  Workstation : ${WORKSTATION_NAME}"
echo "  Public IP   : ${PUBLIC_IP}"
echo "  SSH         : ssh -i ${KEY_FILE} ec2-user@${PUBLIC_IP}"
