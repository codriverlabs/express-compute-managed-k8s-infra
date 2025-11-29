#!/bin/bash
set -e

STACK_NAME="${1:-eks-d-stack}"
REGION="${2:-us-east-1}"

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://cloudformation-template.yaml \
  --region "$REGION"

if [ $? -eq 0 ]; then
  echo "✓ Template validation successful"
else
  echo "✗ Template validation failed"
  exit 1
fi

echo ""
echo "Deploying CloudFormation stack: $STACK_NAME in region: $REGION"

aws cloudformation deploy \
  --template-file cloudformation-template.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides file://cloudformation-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo "Stack deployment complete!"
echo "Getting outputs..."

aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table
