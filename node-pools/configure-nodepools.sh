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

CLUSTER_NAME="${CLUSTER_NAME:-${DEVELOPER_SIGNUM}-eks-dx}"
ARCH="${3:-arm64}"
OUTPUT_DIR="/opt/eks-d/karpenter_runtime_configuration"

echo "Discovering Karpenter configuration for $DEVELOPER_SIGNUM (cluster: $CLUSTER_NAME)..."

# Discover EKS-Optimized AL2023 AMI for this k8s version and arch
K8S_MINOR=$(kubectl version --output=json 2>/dev/null | python3 -c "import sys,json; v=json.load(sys.stdin)['serverVersion']['minor']; print(v.rstrip('+'))")
AMI_ID=$(aws ssm get-parameter \
  --name "/aws/service/eks/optimized-ami/1.${K8S_MINOR}/amazon-linux-2023/${ARCH}/standard/recommended/image_id" \
  --query Parameter.Value --output text --region "$REGION")
echo "  EKS-Optimized AMI : $AMI_ID (k8s 1.${K8S_MINOR} ${ARCH})"

# Discover AWS resources
# Instance profile follows the same naming convention as the role
INSTANCE_PROFILE="eks-dx-workstation-${DEVELOPER_SIGNUM}"

SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Developer,Values=${DEVELOPER_SIGNUM}" "Name=tag:SubnetType,Values=Private" \
  --query 'Subnets[0].SubnetId' --output text --region "$REGION")

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=eks-dx-workstation-${DEVELOPER_SIGNUM}" \
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
  --set amiId="$AMI_ID" \
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
