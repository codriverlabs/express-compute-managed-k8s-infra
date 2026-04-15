#!/bin/bash
set -e

echo "Installing AWS Cloud Provider..."

# Add Helm repo
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

# Get region from IMDS
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Install cloud-provider-aws with hostNetwork to access IMDS
helm install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set hostNetwork=true \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--use-service-account-credentials=true \
  --wait

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
