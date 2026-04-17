#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-}"
AWS_REGION="${AWS_REGION:-$(curl -sf http://169.254.169.254/latest/meta-data/placement/region)}"

# Fall back to persisted cluster identity
if [ -z "$CLUSTER_NAME" ]; then
  [ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env
fi

echo "Installing CloudWatch Observability agent..."

helm repo add aws-observability https://aws-observability.github.io/helm-charts
helm repo update

helm upgrade --install amazon-cloudwatch-observability aws-observability/amazon-cloudwatch-observability \
  --namespace amazon-cloudwatch \
  --create-namespace \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --wait

echo "✓ CloudWatch agent installed"
kubectl get pods -n amazon-cloudwatch
