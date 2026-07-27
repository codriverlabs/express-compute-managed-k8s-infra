#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
PROJECT_NAME="${2:-express-compute-managed-k8s-infra}"

echo "╔══════════════════════════════════════════════╗"
echo "║   Express Compute Shared VPC — Destroy (CDK)          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region:  ${REGION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

export CDK_DEFAULT_REGION="${REGION}"
export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

cd "$(dirname "$0")/infra"

cdk destroy ExpressComputeManagedK8sInfraStack \
  --context projectName="${PROJECT_NAME}" \
  --force
