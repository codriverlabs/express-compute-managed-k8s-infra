#!/bin/bash

set -e

# Get cluster info from Terraform outputs or environment
CLUSTER_NAME=${CLUSTER_NAME:-$(kubectl config current-context)}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-$(aws configure get region)}

echo "Installing Karpenter for cluster: ${CLUSTER_NAME}"

# Add Karpenter Helm repository
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Create Karpenter namespace
kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -

# Install Karpenter
helm upgrade --install karpenter karpenter/karpenter \
  --version "0.32.1" \
  --namespace karpenter \
  --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.defaultInstanceProfile=KarpenterNodeInstanceProfile" \
  --set "settings.interruptionQueueName=${CLUSTER_NAME}" \
  --set "controller.resources.requests.cpu=1" \
  --set "controller.resources.requests.memory=1Gi" \
  --set "controller.resources.limits.cpu=1" \
  --set "controller.resources.limits.memory=1Gi" \
  --wait

# Wait for Karpenter to be ready
echo "Waiting for Karpenter to be ready..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s

echo "Karpenter installation complete!"
echo "Next step: Apply NodePool configurations from ../node-pools/"
