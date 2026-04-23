#!/bin/bash
set -e

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="eks-dx-tfstate-${ACCOUNT_ID}"

echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX VPC — Destroy                       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region: ${REGION}"
echo ""

cd "$(dirname "$0")/terraform/vpc"

# Initialize backend
terraform init \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=vpc/terraform.tfstate" \
  -backend-config="region=${REGION}"

# Destroy
terraform destroy \
  -var="aws_region=${REGION}" \
  -auto-approve

echo ""
echo "==> VPC destroyed successfully!"
