#!/bin/bash
set -e

echo "Installing AWS Cloud Provider..."

helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

helm install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set hostNetwork=true \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].effect="NoSchedule" \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--use-service-account-credentials=true \
  --wait

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
