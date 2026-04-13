#!/bin/bash
set -e

REGION="${1:-us-east-1}"

echo "Validating shared VPC template..."
aws cloudformation validate-template \
  --template-body file://shared-vpc-template.yaml \
  --region "$REGION" > /dev/null

echo "✓ Shared VPC template is valid"

echo ""
echo "Validating developer stack template..."
aws cloudformation validate-template \
  --template-body file://developer-stack-template.yaml \
  --region "$REGION" > /dev/null

echo "✓ Developer stack template is valid"

echo ""
echo "✓ All templates are valid!"
