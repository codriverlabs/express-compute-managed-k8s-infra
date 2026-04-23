#!/bin/bash
set -e

REGION=$1
EKS_VERSION=$2      # 1.35 (for AL2023 AMI lookup)
EKSD_VERSION=$3     # 1.35.8 (for EKS-D compatibility)

echo "Finding AL2023 EKS-optimized AMIs for EKS ${EKS_VERSION}..."

# Find latest AL2023 EKS-optimized AMIs
ARM64_AMI=$(aws ec2 describe-images --region "$REGION" --owners amazon \
  --filters "Name=name,Values=amazon-eks-node-al2023-arm64-standard-$EKS_VERSION-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)

X86_AMI=$(aws ec2 describe-images --region "$REGION" --owners amazon \
  --filters "Name=name,Values=amazon-eks-node-al2023-x86_64-standard-$EKS_VERSION-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)

if [ "$ARM64_AMI" = "None" ] || [ "$X86_AMI" = "None" ]; then
  echo "❌ Could not find AL2023 AMIs for EKS ${EKS_VERSION} in ${REGION}"
  echo "   ARM64: $ARM64_AMI"
  echo "   x86_64: $X86_AMI"
  exit 1
fi

echo "Found AMIs:"
echo "  ARM64: $ARM64_AMI"
echo "  x86_64: $X86_AMI"

# Tag AMIs with both versions
for ami in $ARM64_AMI $X86_AMI; do
  echo "Tagging $ami..."
  aws ec2 create-tags --region "$REGION" --resources "$ami" --tags \
    Key=Name,Value="eks-dx-$EKS_VERSION-$ami" \
    Key=EKSVersion,Value="$EKS_VERSION" \
    Key=EKSDVersion,Value="$EKSD_VERSION" \
    Key=KarpenterReady,Value=true
done

echo "✓ Tagged AL2023 AMIs for EKS ${EKS_VERSION} / EKS-D ${EKSD_VERSION}"
