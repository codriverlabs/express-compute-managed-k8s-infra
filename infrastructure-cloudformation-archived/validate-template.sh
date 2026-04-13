#!/bin/bash
set -e

REGION="${1:-us-east-1}"

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://cloudformation-template.yaml \
  --region "$REGION"

echo ""
echo "✓ Template is valid!"
