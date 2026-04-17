#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-eks-d}"
AWS_REGION="${AWS_REGION:-$(curl -sf http://169.254.169.254/latest/meta-data/placement/region)}"

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
