#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
PROJECT_NAME="${2:-eks-dx}"

echo "╔══════════════════════════════════════════════╗"
echo "║   EKS-DX Shared VPC — Deploy (CDK)           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region:  ${REGION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

export CDK_DEFAULT_REGION="${REGION}"
export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

cd "$(dirname "$0")/cdk"

cdk deploy EksDxSharedInfraStack \
  --context projectName="${PROJECT_NAME}" \
  --require-approval never
