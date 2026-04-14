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

# Use pre-downloaded chart if available
CHART_PATH=$(ls /opt/eks-d/charts/karpenter-*.tgz 2>/dev/null | head -1)
if [ -n "$CHART_PATH" ]; then
  helm upgrade --install karpenter "$CHART_PATH" \
    --namespace karpenter \
    --create-namespace \
    --set settings.clusterName=${CLUSTER_NAME} \
    --set settings.interruptionQueue=${CLUSTER_NAME} \
    --set controller.resources.requests.cpu=1 \
    --set controller.resources.requests.memory=1Gi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --wait
else
  helm repo add karpenter https://charts.karpenter.sh
  helm repo update
  helm upgrade --install karpenter karpenter/karpenter \
    --namespace karpenter \
    --create-namespace \
    --set settings.clusterName=${CLUSTER_NAME} \
    --set settings.interruptionQueue=${CLUSTER_NAME} \
    --set controller.resources.requests.cpu=1 \
    --set controller.resources.requests.memory=1Gi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --wait
fi

echo "✓ Karpenter installed"
kubectl get pods -n karpenter
