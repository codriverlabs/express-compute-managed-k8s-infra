#!/bin/bash
set -e

STACK_NAME="${1:-eks-d-stack}"
REGION="${2:-us-east-1}"

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
