#!/bin/bash
set -e

echo "Installing AWS Cloud Provider..."

# Add Helm repo
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

# Install cloud-provider-aws with hostNetwork to access IMDS
helm install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--use-service-account-credentials=true \
  --wait

# Patch to enable hostNetwork
kubectl patch daemonset aws-cloud-controller-manager -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/hostNetwork","value":true}]'

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
