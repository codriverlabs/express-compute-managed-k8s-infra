#!/bin/bash
set -e

echo "Installing AWS VPC CNI v1.20.4..."

# Use pre-downloaded manifest if available
if [ -f /opt/eks-d/manifests/aws-vpc-cni.yaml ]; then
  kubectl apply -f /opt/eks-d/manifests/aws-vpc-cni.yaml
else
  kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml
fi

echo "Waiting for CNI pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=aws-node -n kube-system --timeout=300s

echo "✓ AWS VPC CNI installed"
kubectl get pods -n kube-system -l k8s-app=aws-node
