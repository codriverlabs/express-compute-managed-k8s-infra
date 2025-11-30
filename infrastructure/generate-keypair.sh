#!/bin/bash
set -e

# Usage: ./generate-keypair.sh <developer-signum> [region]

if [ $# -lt 1 ]; then
  echo "Usage: $0 <developer-signum> [region]"
  echo ""
  echo "Arguments:"
  echo "  developer-signum : Developer name (lowercase, hyphens only)"
  echo "  region          : AWS region (default: us-east-1)"
  echo ""
  echo "Example:"
  echo "  $0 alice"
  echo "  $0 bob us-west-2"
  exit 1
fi

DEVELOPER_SIGNUM="$1"
REGION="${2:-us-east-1}"
KEY_NAME="${DEVELOPER_SIGNUM}-eks-d-key"
KEY_FILE="${HOME}/.ssh/${KEY_NAME}.pem"

echo "=========================================="
echo "Generating EC2 Key Pair"
echo "=========================================="
echo "Developer:   ${DEVELOPER_SIGNUM}"
echo "Key Name:    ${KEY_NAME}"
echo "Region:      ${REGION}"
echo "Key File:    ${KEY_FILE}"
echo "=========================================="
echo ""

# Validate developer signum format
if ! [[ "$DEVELOPER_SIGNUM" =~ ^[a-z0-9-]+$ ]]; then
  echo "Error: Developer signum must contain only lowercase letters, numbers, and hyphens"
  exit 1
fi

# Check if key already exists in AWS
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
  echo "Warning: Key pair '${KEY_NAME}' already exists in AWS"
  read -p "Do you want to delete and recreate it? (yes/no): " CONFIRM
  if [ "$CONFIRM" = "yes" ]; then
    echo "Deleting existing key pair from AWS..."
    aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"
    echo "✓ Deleted"
  else
    echo "Keeping existing key pair"
    exit 0
  fi
fi

# Check if key file already exists locally
if [ -f "$KEY_FILE" ]; then
  echo "Warning: Key file already exists locally: ${KEY_FILE}"
  read -p "Do you want to overwrite it? (yes/no): " CONFIRM
  if [ "$CONFIRM" = "yes" ]; then
    echo "Backing up existing key file..."
    mv "$KEY_FILE" "${KEY_FILE}.backup.$(date +%s)"
    echo "✓ Backed up"
  else
    echo "Keeping existing key file"
    exit 0
  fi
fi

# Create .ssh directory if it doesn't exist
mkdir -p "${HOME}/.ssh"

# Generate key pair
echo "Creating key pair in AWS..."
aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --region "$REGION" \
  --query 'KeyMaterial' \
  --output text > "$KEY_FILE"

# Set proper permissions
chmod 400 "$KEY_FILE"

echo ""
echo "=========================================="
echo "✓ Key pair created successfully!"
echo "=========================================="
echo ""
echo "Key Details:"
echo "  AWS Key Name: ${KEY_NAME}"
echo "  Local File:   ${KEY_FILE}"
echo "  Permissions:  400 (read-only)"
echo ""
echo "Next Steps:"
echo "1. Keep this key file safe - it cannot be recovered if lost"
echo "2. Use this key name when deploying: ./deploy-developer.sh ${DEVELOPER_SIGNUM} <subnet-index> ${KEY_NAME}"
echo ""
echo "SSH Command Format:"
echo "  ssh -i ${KEY_FILE} ec2-user@<instance-ip>"
echo ""
echo "To delete this key pair later:"
echo "  aws ec2 delete-key-pair --key-name ${KEY_NAME} --region ${REGION}"
echo "  rm ${KEY_FILE}"
