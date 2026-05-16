#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${TFSTATE_BUCKET:-eks-dx-tfstate-${ACCOUNT_ID}-${AWS_REGION}}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Full Teardown                       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region:       ${AWS_REGION}"
echo "  State bucket: ${BUCKET}"
echo ""
echo "  WARNING: This will permanently destroy ALL workstations,"
echo "  the shared VPC, and the Terraform state bucket."
echo "  This operation is IRREVERSIBLE."
echo ""
read -rp "  Type 'destroy-all' to confirm: " CONFIRM
[ "${CONFIRM}" != "destroy-all" ] && { echo "Aborted."; exit 0; }

# ── 1. Destroy all workstations ──────────────────────────────────────────────
echo ""
echo "==> Discovering workstations in state bucket..."

WORKSTATION_KEYS=$(aws s3api list-objects-v2 \
  --bucket "${BUCKET}" \
  --prefix "eks-dx/" \
  --query "Contents[?ends_with(Key, '/terraform.tfstate')].Key" \
  --output text \
  --region "${AWS_REGION}" 2>/dev/null || true)

for KEY in ${WORKSTATION_KEYS}; do
  # Skip the VPC state
  [ "${KEY}" = "vpc/terraform.tfstate" ] && continue

  WORKSTATION_NAME=$(echo "${KEY}" | sed 's|eks-dx/||;s|/terraform.tfstate||')
  echo ""
  echo "  Destroying workstation: ${WORKSTATION_NAME}"

  terraform -chdir="${SCRIPT_DIR}/terraform" init -reconfigure \
    -backend-config="bucket=${BUCKET}" \
    -backend-config="key=${KEY}" \
    -backend-config="region=${AWS_REGION}" \
    -input=false 2>&1 | tail -3

  terraform -chdir="${SCRIPT_DIR}/terraform" destroy \
    -auto-approve \
    -input=false || echo "  WARNING: destroy failed for ${WORKSTATION_NAME}, continuing..."
done

# ── 2. Destroy VPC ───────────────────────────────────────────────────────────
echo ""
echo "==> Destroying shared VPC..."

cd "${SCRIPT_DIR}/terraform/vpc"
terraform init -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=vpc/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -input=false 2>&1 | tail -3

terraform destroy \
  -var="aws_region=${AWS_REGION}" \
  -auto-approve \
  -input=false || echo "  WARNING: VPC destroy failed, continuing..."
cd "${SCRIPT_DIR}"

# ── 3. Delete state bucket ───────────────────────────────────────────────────
echo ""
echo "==> Deleting Terraform state bucket: ${BUCKET}..."

# Delete all versioned objects first
aws s3api delete-objects \
  --bucket "${BUCKET}" \
  --region "${AWS_REGION}" \
  --delete "$(aws s3api list-object-versions \
    --bucket "${BUCKET}" \
    --region "${AWS_REGION}" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" > /dev/null 2>&1 || true

# Delete all delete markers
aws s3api delete-objects \
  --bucket "${BUCKET}" \
  --region "${AWS_REGION}" \
  --delete "$(aws s3api list-object-versions \
    --bucket "${BUCKET}" \
    --region "${AWS_REGION}" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json)" > /dev/null 2>&1 || true

aws s3api delete-bucket --bucket "${BUCKET}" --region "${AWS_REGION}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Full teardown complete                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
