#!/bin/bash
set -e

[ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env

echo "Installing AWS Cloud Provider..."

helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

helm upgrade --install aws-cloud-controller-manager \
  aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].effect="NoSchedule" \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--configure-cloud-routes=false \
  --set args[3]=--cluster-name="${CLUSTER_NAME}" \
  --wait

# The chart doesn't support hostNetwork via values — patch directly.
# Required so the pod can reach IMDS at 169.254.169.254 (link-local).
kubectl patch daemonset aws-cloud-controller-manager -n kube-system \
  --patch '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

echo "✓ AWS Cloud Provider installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cloud-controller-manager
