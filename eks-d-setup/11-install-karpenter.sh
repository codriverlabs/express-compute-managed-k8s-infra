#!/bin/bash
set -e

DEVELOPER_SIGNUM="${1:-${DEVELOPER_SIGNUM:-}}"
CLUSTER_NAME="${2:-${CLUSTER_NAME:-}}"

# Fall back to persisted cluster identity
if [ -z "$DEVELOPER_SIGNUM" ] || [ -z "$CLUSTER_NAME" ]; then
  [ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env
fi

if [ -z "$DEVELOPER_SIGNUM" ] || [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <developer-signum> <cluster-name>"
  exit 1
fi

export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# On EKS-D, there is no EKS managed control plane — Karpenter cannot use DescribeCluster.
# clusterEndpoint must be set explicitly to the API server address.
CLUSTER_ENDPOINT="https://$(hostname -I | awk '{print $1}'):6443"

KARPENTER_VERSION="1.10.0"

echo "Installing Karpenter ${KARPENTER_VERSION}..."
echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"

# Karpenter moved to OCI registry — helm repo add no longer works
# Logout first to allow unauthenticated pull from public ECR
helm registry logout public.ecr.aws 2>/dev/null || true

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace kube-system \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.interruptionQueue=${CLUSTER_NAME} \
  --set settings.eksControlPlane=false \
  --set replicas=1 \
  --set controller.resources.requests.cpu=500m \
  --set controller.resources.requests.memory=512Mi \
  --set controller.resources.limits.cpu=500m \
  --set controller.resources.limits.memory=512Mi \
  --set topologySpreadConstraints=null \
  --set controller.env[0].name=AWS_REGION \
  --set controller.env[0].value=${AWS_REGION} \
  --set dnsPolicy=Default \
  --wait

echo "✓ Karpenter installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
