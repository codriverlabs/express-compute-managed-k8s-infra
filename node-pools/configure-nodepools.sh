#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load cluster identity
[ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env

DEVELOPER_SIGNUM="${1:-${DEVELOPER_SIGNUM}}"
REGION="${2:-${AWS_REGION:-us-east-1}}"

if [ -z "$DEVELOPER_SIGNUM" ]; then
  echo "Usage: $0 <developer-signum> [region]"
  exit 1
fi

CLUSTER_NAME="${CLUSTER_NAME:-${DEVELOPER_SIGNUM}-eks-d}"
OUTPUT_DIR="/opt/eks-d/karpenter_runtime_configuration"

echo "Discovering Karpenter configuration for $DEVELOPER_SIGNUM (cluster: $CLUSTER_NAME)..."

# Discover AWS resources
INSTANCE_PROFILE=$(aws iam list-instance-profiles-for-role \
  --role-name "eks-d-workstation-${DEVELOPER_SIGNUM}" \
  --query 'InstanceProfiles[0].InstanceProfileName' \
  --output text --region "$REGION")

SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Developer,Values=${DEVELOPER_SIGNUM}" "Name=tag:SubnetType,Values=Private" \
  --query 'Subnets[0].SubnetId' --output text --region "$REGION")

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=eks-d-workstation-${DEVELOPER_SIGNUM}" \
  --query 'SecurityGroups[0].GroupId' --output text --region "$REGION")

# Discover cluster details
API_SERVER="https://$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}'):6443"
CA_BUNDLE=$(sudo cat /etc/kubernetes/pki/ca.crt 2>/dev/null | base64 -w0 || \
            kubectl get configmap kube-root-ca.crt -n kube-system -o jsonpath='{.data.ca\.crt}' | base64 -w0)
SERVICE_CIDR=$(kubectl get configmap kubeadm-config -n kube-system \
  -o jsonpath='{.data.ClusterConfiguration}' | grep serviceSubnet | awk '{print $2}')

echo "  Instance Profile : $INSTANCE_PROFILE"
echo "  Subnet           : $SUBNET_ID"
echo "  Security Group   : $SECURITY_GROUP_ID"
echo "  API Server       : $API_SERVER"
echo "  Service CIDR     : $SERVICE_CIDR"

# Render chart and persist
sudo mkdir -p "$OUTPUT_DIR"

helm template eks-d-karpenter "${SCRIPT_DIR}/chart" \
  --set clusterName="$CLUSTER_NAME" \
  --set developerSignum="$DEVELOPER_SIGNUM" \
  --set awsRegion="$REGION" \
  --set instanceProfile="$INSTANCE_PROFILE" \
  --set subnetId="$SUBNET_ID" \
  --set securityGroupId="$SECURITY_GROUP_ID" \
  --set nodeConfig.apiServerEndpoint="$API_SERVER" \
  --set nodeConfig.certificateAuthority="$CA_BUNDLE" \
  --set nodeConfig.serviceCidr="$SERVICE_CIDR" \
  | sudo tee "$OUTPUT_DIR/karpenter-manifests.yaml" > /dev/null

echo "✓ Rendered manifests saved to $OUTPUT_DIR/karpenter-manifests.yaml"

# Apply
kubectl apply -f "$OUTPUT_DIR/karpenter-manifests.yaml"

echo "✓ NodePool and EC2NodeClass applied."
echo "  To re-apply without re-discovery: kubectl apply -f $OUTPUT_DIR/karpenter-manifests.yaml"
