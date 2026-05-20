#!/bin/bash
set -e

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="eks-dx-tfstate-${ACCOUNT_ID}-${REGION}"

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

# Delete VPC flow log group before destroy — CloudWatch retains non-empty log groups
# and terraform destroy fails with ResourceAlreadyExistsException on re-provision
LOG_GROUP="/aws/vpc/${REGION}/eks-dx-flow-logs"
echo "==> Deleting CloudWatch log group ${LOG_GROUP}..."
aws logs delete-log-group --log-group-name "${LOG_GROUP}" --region "${REGION}" 2>/dev/null || true

# Destroy
terraform destroy \
  -var="aws_region=${REGION}" \
  -auto-approve

echo ""
echo "==> VPC destroyed successfully!"
