#!/bin/bash
set -e

REGION="${1:-us-east-1}"
PROJECT_NAME="${2:-eks-d}"

echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-D Shared VPC — Deploy                  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region: ${REGION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

# Check if AMI builder images are available
AMI_X86="/eks-d/ami/x86_64"
AMI_ARM="/eks-d/ami/arm64"

if aws ssm get-parameter --name "${AMI_X86}" --region "${REGION}" >/dev/null 2>&1 || \
   aws ssm get-parameter --name "${AMI_ARM}" --region "${REGION}" >/dev/null 2>&1; then
  echo "ℹ️  AMI builder image(s) found in SSM Parameter Store"
  echo "   Consider using './deploy.sh' for complete developer environment setup"
  echo ""
else
  echo "ℹ️  No AMI builder images found in SSM Parameter Store"
  echo "   Sequence: 1) Build AMI first, 2) Then use './deploy.sh'"
  echo ""
fi

cd "$(dirname "$0")/terraform/vpc"

# Initialize Terraform
terraform init

# Plan
terraform plan \
  -var="aws_region=${REGION}" \
  -var="project_name=${PROJECT_NAME}"

# Apply
read -p "Apply changes? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

terraform apply \
  -var="aws_region=${REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -auto-approve

echo ""
echo "==> VPC deployed successfully!"
echo ""
terraform output
