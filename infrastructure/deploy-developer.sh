#!/bin/bash
set -e

# Usage: ./deploy-developer.sh <developer-signum> <subnet-index> <key-pair-name> [enable-userdata]

if [ $# -lt 3 ]; then
  echo "Usage: $0 <developer-signum> <subnet-index> <key-pair-name> [enable-userdata]"
  echo ""
  echo "Arguments:"
  echo "  developer-signum  : Developer name (lowercase, hyphens only)"
  echo "  subnet-index      : Unique subnet index (1-50)"
  echo "  key-pair-name     : EC2 key pair name"
  echo "  enable-userdata   : true or false (default: false for manual testing)"
  echo ""
  echo "Example:"
  echo "  $0 alice 1 my-key-pair false"
  exit 1
fi

DEVELOPER_SIGNUM="$1"
SUBNET_INDEX="$2"
KEY_PAIR_NAME="$3"
ENABLE_USERDATA="${4:-false}"
REGION="${5:-us-east-1}"
SHARED_VPC_STACK="${6:-eks-d-shared-vpc}"

STACK_NAME="eks-d-${DEVELOPER_SIGNUM}"

echo "=========================================="
echo "Deploying Developer Stack"
echo "=========================================="
echo "Developer:        ${DEVELOPER_SIGNUM}"
echo "Subnet Index:     ${SUBNET_INDEX}"
echo "Key Pair:         ${KEY_PAIR_NAME}"
echo "Enable UserData:  ${ENABLE_USERDATA}"
echo "Region:           ${REGION}"
echo "Stack Name:       ${STACK_NAME}"
echo "=========================================="
echo ""

# Validate developer signum format
if ! [[ "$DEVELOPER_SIGNUM" =~ ^[a-z0-9-]+$ ]]; then
  echo "Error: Developer signum must contain only lowercase letters, numbers, and hyphens"
  exit 1
fi

# Validate subnet index
if [ "$SUBNET_INDEX" -lt 1 ] || [ "$SUBNET_INDEX" -gt 50 ]; then
  echo "Error: Subnet index must be between 1 and 50"
  exit 1
fi

# Check if shared VPC stack exists
echo "Checking if shared VPC stack exists..."
if ! aws cloudformation describe-stacks --stack-name "$SHARED_VPC_STACK" --region "$REGION" &>/dev/null; then
  echo "Error: Shared VPC stack '${SHARED_VPC_STACK}' not found in ${REGION}"
  echo "Please deploy the shared VPC first: ./deploy-vpc.sh"
  exit 1
fi
echo "✓ Shared VPC stack found"
echo ""

# Check if key pair exists
echo "Checking if key pair exists..."
if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$REGION" &>/dev/null; then
  echo "Error: Key pair '${KEY_PAIR_NAME}' not found in ${REGION}"
  exit 1
fi
echo "✓ Key pair found"
echo ""

# Deploy stack
echo "Deploying developer stack..."
aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://developer-stack-template.yaml \
  --parameters \
    ParameterKey=SharedVpcStackName,ParameterValue="$SHARED_VPC_STACK" \
    ParameterKey=DeveloperName,ParameterValue="$DEVELOPER_SIGNUM" \
    ParameterKey=SubnetIndex,ParameterValue="$SUBNET_INDEX" \
    ParameterKey=KeyPairName,ParameterValue="$KEY_PAIR_NAME" \
    ParameterKey=ControlPlaneInstanceType,ParameterValue=t4a.large \
    ParameterKey=EnableUserData,ParameterValue="$ENABLE_USERDATA" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo ""
echo "Waiting for stack creation to complete..."
echo "This may take 5-10 minutes..."
aws cloudformation wait stack-create-complete \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo ""
echo "=========================================="
echo "✓ Developer stack created successfully!"
echo "=========================================="
echo ""

# Get outputs
echo "Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "Connection Information:"
SSH_COMMAND=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`SSHCommand`].OutputValue' \
  --output text)

KUBE_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`KubeconfigEndpoint`].OutputValue' \
  --output text)

echo "SSH Command:       ${SSH_COMMAND}"
echo "Kubernetes API:    ${KUBE_ENDPOINT}"
echo ""

if [ "$ENABLE_USERDATA" = "false" ]; then
  echo "=========================================="
  echo "Manual Setup Required"
  echo "=========================================="
  echo "UserData is disabled. Follow these steps:"
  echo "1. SSH to the instance: ${SSH_COMMAND}"
  echo "2. Follow the manual setup guide: infrastructure/MANUAL_SETUP.md"
  echo ""
fi

echo "Next Steps:"
echo "- View full outputs: aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION}"
echo "- Delete stack: aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}"
