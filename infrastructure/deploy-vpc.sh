#!/bin/bash
set -e

REGION="${1:-us-east-1}"

echo "Deploying shared VPC stack in ${REGION}..."

aws cloudformation create-stack \
  --stack-name eks-d-shared-vpc \
  --template-body file://shared-vpc-template.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=eks-d \
  --capabilities CAPABILITY_IAM \
  --region "$REGION"

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name eks-d-shared-vpc \
  --region "$REGION"

echo ""
echo "✓ Shared VPC stack created successfully!"
echo ""
echo "Stack outputs:"
aws cloudformation describe-stacks \
  --stack-name eks-d-shared-vpc \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table
