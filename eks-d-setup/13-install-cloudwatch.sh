#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-}"
AWS_REGION="${AWS_REGION:-}"

# Fall back to persisted cluster identity
if [ -z "$CLUSTER_NAME" ]; then
  [ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env
fi

# Get region via IMDSv2
if [ -z "$AWS_REGION" ]; then
  TOKEN=$(curl -sf -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token 2>/dev/null || true)
  AWS_REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || true)
fi

if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ]; then
  echo "ERROR: CLUSTER_NAME and AWS_REGION must be set" >&2; exit 1
fi

echo "Installing CloudWatch Observability agent..."

helm repo add aws-observability https://aws-observability.github.io/helm-charts 2>/dev/null || true
helm repo update

helm upgrade --install amazon-cloudwatch-observability aws-observability/amazon-cloudwatch-observability \
  --namespace amazon-cloudwatch \
  --create-namespace \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --wait

echo "✓ CloudWatch agent installed"
kubectl get pods -n amazon-cloudwatch
