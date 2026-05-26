#!/bin/bash
# 14-install-eks-dx-pod-identity.sh
# Registers the cluster with the EKS-DX control plane and installs
# the Pod Identity compatibility components (auth-proxy + webhook).
#
# Required env vars (set via EC2 user data):
#   EKS_DX_ENDPOINT  — Lambda Function URL base (used by eks-dx CLI)
#   EKS_DX_API_URL   — API Gateway URL (used by in-cluster components)
#   TENANT_ID        — tenant identifier
set -eo pipefail

if [ -z "${EKS_DX_ENDPOINT}" ] || [ -z "${EKS_DX_API_URL}" ]; then
  echo "Skipping EKS-DX Pod Identity integration (EKS_DX_ENDPOINT / EKS_DX_API_URL not set)"
  exit 0
fi

echo "==> Installing EKS-DX Pod Identity integration..."

TOKEN=$(curl -sf -X PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
PUBLIC_IP=$(curl -sf -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

# Derive JWKS from the running cluster
kubectl get --raw /openid/v1/jwks \
  --kubeconfig /etc/kubernetes/admin.conf > /tmp/jwks.json

# Register cluster with EKS-DX control plane
EKS_DX_ENDPOINT="${EKS_DX_ENDPOINT}" \
eks-dx create cluster "${TENANT_ID}" \
  --issuer "https://${PUBLIC_IP}" \
  --jwks-file /tmp/jwks.json
echo "✓ Cluster registered with EKS-DX"

# Install Pod Identity compatibility components
helm install eks-dx-auth-proxy /opt/eks-dx/charts/eks-dx-auth-proxy \
  --namespace kube-system \
  --set app.envs.EKS_DX_ENDPOINT="${EKS_DX_API_URL}" \
  --set app.envs.EKS_CLUSTER_NAME="${TENANT_ID}" \
  --kubeconfig /etc/kubernetes/admin.conf
echo "✓ eks-dx-auth-proxy installed"

helm install eks-dx-pod-identity-webhook /opt/eks-dx/charts/eks-dx-pod-identity-webhook \
  --namespace kube-system \
  --set app.envs.EKS_DX_ENDPOINT="${EKS_DX_API_URL}" \
  --set app.envs.EKS_CLUSTER_NAME="${TENANT_ID}" \
  --kubeconfig /etc/kubernetes/admin.conf
echo "✓ eks-dx-pod-identity-webhook installed"

echo "✓ EKS-DX Pod Identity integration complete"
