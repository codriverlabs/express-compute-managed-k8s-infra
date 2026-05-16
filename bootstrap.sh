#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${1:-us-east-1}"
PROJECT_NAME="${2:-eks-dx}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="eks-dx-tfstate-${ACCOUNT_ID}-${AWS_REGION}"

echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Bootstrap                           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region: ${AWS_REGION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

# 1. Create Terraform state bucket
echo "==> Setting up Terraform state backend..."

if aws s3api head-bucket --bucket "${BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
  echo "    ✓ Bucket exists: ${BUCKET}"
else
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi
  echo "    ✓ Created bucket: ${BUCKET}"
fi

aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws s3api put-bucket-lifecycle-configuration --bucket "${BUCKET}" \
  --lifecycle-configuration '{"Rules":[{"ID":"expire-old-versions","Status":"Enabled","NoncurrentVersionExpiration":{"NoncurrentDays":30},"Filter":{"Prefix":""}}]}'

# 2. Deploy shared VPC if it doesn't exist
echo ""
echo "==> Deploying shared VPC..."

cd "$(dirname "$0")/terraform/vpc"

terraform init -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=vpc/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

terraform apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -auto-approve

VPC_ID=$(terraform output -raw vpc_id)
echo "    ✓ VPC: ${VPC_ID}"
cd - > /dev/null

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Bootstrap Complete                         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  export AWS_REGION=${AWS_REGION}"
echo "  Terraform state bucket: ${BUCKET} (auto-derived)"
echo ""
echo "Next: ./deploy.sh"
echo ""
