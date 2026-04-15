#!/bin/bash
set -e

echo "Installing AWS Cloud Provider..."

# Add Helm repo
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

# Install cloud-provider-aws
helm install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set args={--v=2,--cloud-provider=aws,--use-service-account-credentials=true} \
  --wait

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
