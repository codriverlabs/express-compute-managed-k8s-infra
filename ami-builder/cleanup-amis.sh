#!/bin/bash
set -e

# EKS-D AMI Cleanup Script
# Deletes all EKS-D AMIs owned by the current account

echo "=========================================="
echo "EKS-D AMI Cleanup"
echo "=========================================="

# Get all EKS-D AMIs
AMIS=$(aws ec2 describe-images --owners self --filters "Name=name,Values=eks-d-*" --query "Images[*].{ImageId:ImageId,Name:Name,CreationDate:CreationDate}" --output json)

if [ "$(echo "$AMIS" | jq length)" -eq 0 ]; then
  echo "No EKS-D AMIs found to delete."
  exit 0
fi

echo "Found EKS-D AMIs:"
echo "$AMIS" | jq -r '.[] | "\(.ImageId) - \(.Name) (\(.CreationDate))"'
echo ""

# Confirm deletion
read -p "Delete all these AMIs? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Deleting AMIs and snapshots..."

# Delete each AMI and its snapshots
echo "$AMIS" | jq -r '.[].ImageId' | while read ami_id; do
  echo "Processing $ami_id..."
  
  # Get snapshots for this AMI
  SNAPSHOTS=$(aws ec2 describe-images --image-ids "$ami_id" --query "Images[0].BlockDeviceMappings[?Ebs].Ebs.SnapshotId" --output text | grep -v '^$' || true)
  
  # Delete snapshots first
  if [ -n "$SNAPSHOTS" ]; then
    echo "  Deleting snapshots: $SNAPSHOTS"
    echo "$SNAPSHOTS" | xargs -n1 aws ec2 delete-snapshot --snapshot-id
  fi
  
  # Then deregister AMI
  echo "  Deregistering AMI: $ami_id"
  aws ec2 deregister-image --image-id "$ami_id"
  echo "✓ Deleted $ami_id and associated snapshots"
done

echo ""
echo "✓ All EKS-D AMIs and snapshots deleted successfully!"
