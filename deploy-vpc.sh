#!/bin/bash
set -e

REGION="${1:-us-east-1}"
EKS_VERSION="${2:-1.35}"        # Kubernetes version (for AL2023 AMIs)
EKSD_VERSION="${3:-1.35.8}"     # EKS-D full version (for EKS-D binaries)
PROJECT_NAME="${4:-eks-dx}"

echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Shared VPC — Deploy                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region: ${REGION}"
echo "  EKS Version: ${EKS_VERSION}"
echo "  EKS-D Version: ${EKSD_VERSION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

# Check if AMI builder images are available
AMI_X86="/eks-dx/ami/x86_64"
AMI_ARM="/eks-dx/ami/arm64"

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

# Tag AL2023 AMIs for this VPC's EKS version
echo "Tagging AL2023 AMIs for EKS ${EKS_VERSION}..."
./tag-vpc-amis.sh "${REGION}" "${EKS_VERSION}" "${EKSD_VERSION}"

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
  -var="eks_version=${EKS_VERSION}" \
  -var="eksd_version=${EKSD_VERSION}" \
  -auto-approve

echo ""
echo "==> VPC deployed successfully!"
echo ""
terraform output
