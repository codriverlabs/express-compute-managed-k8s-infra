#!/bin/bash
set -e

echo "Installing EBS CSI Driver v1.38.0 via Helm..."
CHART=$(ls /opt/eks-d/charts/aws-ebs-csi-driver-*.tgz 2>/dev/null | head -1)
if [ -z "$CHART" ]; then
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  CHART="aws-ebs-csi-driver/aws-ebs-csi-driver"
fi
helm upgrade --install aws-ebs-csi-driver "$CHART" \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --wait

echo "Creating default storage class..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

echo "✓ EBS CSI Driver installed"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
kubectl get storageclass
