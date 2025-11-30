#!/bin/bash
set -e

echo "Installing CoreDNS..."
kubectl apply -f https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed

echo "Waiting for CoreDNS pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=300s

echo "✓ CoreDNS installed"
kubectl get pods -n kube-system -l k8s-app=kube-dns
