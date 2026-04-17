#!/bin/bash
set -e

echo "Installing AWS Cloud Provider..."

helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

helm install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].effect="NoSchedule" \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--use-service-account-credentials=true \
  --set args[3]=--configure-cloud-routes=false \
  --wait

# The chart doesn't support hostNetwork via values — patch directly.
# Required so the pod can reach IMDS at 169.254.169.254 (link-local).
kubectl patch daemonset aws-cloud-controller-manager -n kube-system \
  --patch '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
