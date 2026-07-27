#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
PROJECT_NAME="${2:-express-compute-managed-k8s-infra}"
INSTANCE_TYPE_ARM64="${3:-c6g.xlarge}"
INSTANCE_TYPE_X86="${4:-m7i.large}"
DISK_SIZE_GB="${5:-20}"
ENABLE_NAT_GATEWAY="${6:-false}"

echo "╔══════════════════════════════════════════════╗"
echo "║   Express Compute Shared VPC — Deploy (CDK)           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Region:  ${REGION}"
echo "  Project: ${PROJECT_NAME}"
echo ""

export CDK_DEFAULT_REGION="${REGION}"
export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

CDK_DIR="$(dirname "$0")/infra"

echo "==> Bootstrapping CDK environment (idempotent)..."
cdk bootstrap "aws://${CDK_DEFAULT_ACCOUNT}/${REGION}" --quiet
echo "    ✓ CDK bootstrap complete"

echo ""
echo "==> Building CDK bundle (mvn compile)..."
mvn -e -q clean compile -f "${CDK_DIR}/pom.xml"
echo "    ✓ CDK bundle built"

echo ""
echo "==> Synthesizing CloudFormation template..."
cd "${CDK_DIR}"
cdk synth ExpressComputeManagedK8sInfraStack \
  --context projectName="${PROJECT_NAME}" \
  --quiet
echo "    ✓ Template: cdk/cdk.out/ExpressComputeManagedK8sInfraStack.template.json"

echo ""
echo "==> Deploying shared infrastructure..."
cdk deploy ExpressComputeManagedK8sInfraStack \
  --context projectName="${PROJECT_NAME}" \
  --parameters ExpressComputeManagedK8sInfraStack:ProjectName="${PROJECT_NAME}" \
  --parameters ExpressComputeManagedK8sInfraStack:InstanceTypeArm64="${INSTANCE_TYPE_ARM64}" \
  --parameters ExpressComputeManagedK8sInfraStack:InstanceTypeX86="${INSTANCE_TYPE_X86}" \
  --parameters ExpressComputeManagedK8sInfraStack:DiskSizeGb="${DISK_SIZE_GB}" \
  --parameters ExpressComputeManagedK8sInfraStack:EnableNatGateway="${ENABLE_NAT_GATEWAY}" \
  --parameters ExpressComputeManagedK8sInfraStack:Region="${REGION}" \
  --require-approval never

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Shared infrastructure deployed             ║"
echo "╚══════════════════════════════════════════════╝"
