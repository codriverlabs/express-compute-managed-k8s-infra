#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1}"
CLUSTER_NAME="${2}"

if [ -z "$DEVELOPER_SIGNUM" ] || [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <developer-signum> <cluster-name>"
  exit 1
fi

export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Installing Karpenter 1.8.2..."
echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"

# Add Karpenter Helm repo
helm repo add karpenter https://charts.karpenter.sh
helm repo update

# Install Karpenter
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --version 1.8.2 \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.interruptionQueue=${CLUSTER_NAME} \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait

echo "✓ Karpenter installed"
kubectl get pods -n karpenter
