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
