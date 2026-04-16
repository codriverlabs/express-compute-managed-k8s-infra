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
echo "Deleting AMIs..."

# Delete each AMI
echo "$AMIS" | jq -r '.[].ImageId' | while read ami_id; do
  echo "Deleting $ami_id..."
  aws ec2 deregister-image --image-id "$ami_id"
  echo "✓ Deregistered $ami_id"
done

echo ""
echo "✓ All EKS-D AMIs deleted successfully!"
echo ""
echo "Checking for associated snapshots..."
SNAPSHOTS=$(aws ec2 describe-snapshots --owner-ids self --query "Snapshots[?contains(Description, 'eks-d')].SnapshotId" --output text | grep -v '^$')

if [ -n "$SNAPSHOTS" ]; then
  echo "Found EKS-D snapshots to clean up:"
  echo "$SNAPSHOTS"
  echo "$SNAPSHOTS" | xargs -n1 aws ec2 delete-snapshot --snapshot-id
  echo "✓ Snapshots deleted"
else
  echo "✓ No EKS-D snapshots found (likely cleaned up automatically)"
fi
