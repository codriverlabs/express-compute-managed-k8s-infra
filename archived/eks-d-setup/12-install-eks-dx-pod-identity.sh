#!/bin/bash
# 12-install-eks-dx-pod-identity.sh
# Registers the cluster with the EKS-DX control plane and installs
# Pod Identity components: auth-proxy, webhook, and the AWS agent DaemonSet.
#
# Prerequisites: cert-manager (11-install-cert-manager.sh)
# Required env (via cluster.env / EC2 user data):
#   EKS_DX_ENDPOINT  — credential service URL (Lambda Function URL or API Gateway)
#   CLUSTER_NAME     — cluster identifier
#   AWS_REGION       — region
set -eo pipefail

[ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env
[ -f /opt/eks-d/version.env ] && source /opt/eks-d/version.env

EKS_DX_CONTROL_PLANE_VERSION="${EKS_DX_CONTROL_PLANE_VERSION:-1.0.0-rc1}"

if [ -z "${EKS_DX_ENDPOINT:-}" ]; then
  echo "Skipping EKS-DX Pod Identity (EKS_DX_ENDPOINT not set)"
  exit 0
fi

if [ -z "${CLUSTER_NAME:-}" ] || [ -z "${AWS_REGION:-}" ]; then
  echo "Error: CLUSTER_NAME and AWS_REGION required in /opt/eks-d/cluster.env"
  exit 1
fi

echo "==> Installing EKS-DX Pod Identity integration..."
echo "    Cluster: ${CLUSTER_NAME}  Region: ${AWS_REGION}"
echo "    Endpoint: ${EKS_DX_ENDPOINT}"

# --- 1. Register cluster with EKS-DX control plane ---
echo "--- Registering cluster..."

# Extract OIDC issuer URL (the API server's --service-account-issuer)
ISSUER=$(kubectl get --raw /.well-known/openid-configuration 2>/dev/null | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['issuer'])" 2>/dev/null || true)

if [ -z "$ISSUER" ]; then
  # Fallback: use cluster endpoint as issuer
  ISSUER="${CLUSTER_ENDPOINT:-https://$(hostname -I | awk '{print $1}'):6443}"
fi

# Fetch JWKS from running API server
kubectl get --raw /openid/v1/jwks > /tmp/jwks.json

eks-dx create cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --endpoint "${EKS_DX_ENDPOINT}" \
  --issuer "${ISSUER}" \
  --jwks-file /tmp/jwks.json || {
    # Cluster may already be registered (idempotent re-runs)
    echo "Warning: cluster registration returned non-zero (may already exist)"
}
echo "✓ Cluster registered"

# --- 2. Install eks-dx-auth-proxy ---
echo "--- Installing eks-dx-auth-proxy..."
CHART=$(ls /opt/eks-d/charts/eks-dx-auth-proxy-*.tgz 2>/dev/null | head -1)
if [ -z "$CHART" ]; then
  CHART="oci://ghcr.io/plasticity-of-cloud/helm/eks-dx-auth-proxy --version ${EKS_DX_CONTROL_PLANE_VERSION}"
fi

helm upgrade --install eks-dx-auth-proxy $CHART \
  --namespace kube-system \
  --set app.envs.EKS_DX_ENDPOINT="${EKS_DX_ENDPOINT}" \
  --set app.envs.AWS_REGION="${AWS_REGION}" \
  --wait --timeout=60s
echo "✓ eks-dx-auth-proxy installed"

# --- 3. Install eks-dx-pod-identity-webhook ---
echo "--- Installing eks-dx-pod-identity-webhook..."
CHART=$(ls /opt/eks-d/charts/eks-dx-pod-identity-webhook-*.tgz 2>/dev/null | head -1)
if [ -z "$CHART" ]; then
  CHART="oci://ghcr.io/plasticity-of-cloud/helm/eks-dx-pod-identity-webhook --version ${EKS_DX_CONTROL_PLANE_VERSION}"
fi

helm upgrade --install eks-dx-pod-identity-webhook $CHART \
  --namespace kube-system \
  --set app.envs.EKS_DX_ENDPOINT="${EKS_DX_ENDPOINT}" \
  --set app.envs.EKS_CLUSTER_NAME="${CLUSTER_NAME}" \
  --set app.envs.AWS_REGION="${AWS_REGION}" \
  --wait --timeout=60s
echo "✓ eks-dx-pod-identity-webhook installed"

# --- 4. Install eks-pod-identity-agent (AWS DaemonSet) ---
# The agent intercepts credential requests at 169.254.170.23 and forwards
# them to eks-dx-auth-proxy instead of the AWS-managed EKS endpoint.
echo "--- Installing eks-pod-identity-agent..."

# Create ECR pull secret (agent image is in AWS ECR us-west-2)
kubectl create secret docker-registry ecr-pod-identity-agent \
  --namespace kube-system \
  --docker-server=602401143452.dkr.ecr.us-west-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region us-west-2)" \
  --dry-run=client -o yaml | kubectl apply -f -

AGENT_CHART=$(ls /opt/eks-d/charts/eks-pod-identity-agent-*.tgz 2>/dev/null | head -1)
if [ -z "$AGENT_CHART" ]; then
  # Clone chart from upstream (no OCI registry available for this chart)
  AGENT_CHART="/tmp/eks-pod-identity-agent/charts/eks-pod-identity-agent"
  if [ ! -d "$AGENT_CHART" ]; then
    git clone --depth=1 https://github.com/aws/eks-pod-identity-agent.git /tmp/eks-pod-identity-agent
  fi
fi

helm upgrade --install eks-pod-identity-agent "$AGENT_CHART" \
  --namespace kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set env.AWS_REGION="${AWS_REGION}" \
  --set "agent.additionalArgs.--endpoint=http://eks-dx-auth-proxy.kube-system.svc.cluster.local:8080" \
  --set "affinity=" \
  --set "imagePullSecrets[0].name=ecr-pod-identity-agent" \
  --wait --timeout=60s
echo "✓ eks-pod-identity-agent installed"

echo "✓ EKS-DX Pod Identity integration complete"
