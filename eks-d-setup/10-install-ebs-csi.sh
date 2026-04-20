#!/bin/bash
set -e

echo "Installing EBS CSI Driver v1.38.0 via Helm..."
CHART=$(ls /opt/eks-d/charts/aws-ebs-csi-driver-*.tgz 2>/dev/null | head -1)
if [ -z "$CHART" ]; then
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  CHART="aws-ebs-csi-driver/aws-ebs-csi-driver"
fi

# Get cluster name from persisted identity
[ -f /opt/eks-d/cluster.env ] && source /opt/eks-d/cluster.env
CLUSTER_NAME="${CLUSTER_NAME:-$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)}"

helm upgrade --install aws-ebs-csi-driver "$CHART" \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --set controller.k8sTagClusterId="$CLUSTER_NAME" \
  --set controller.replicaCount=1 \
  --wait

# Use node DNS (dnsPolicy: Default) to bypass CoreDNS external forwarding issue.
# CoreDNS on EKS-D fails to forward external queries; the node's /etc/resolv.conf
# points directly to the VPC DNS resolver (10.0.0.2) which works correctly.
kubectl patch deployment ebs-csi-controller -n kube-system \
  --patch '{"spec":{"template":{"spec":{"dnsPolicy":"Default"}}}}'

# Tag the current instance for EBS CSI cluster scoping
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --resources "$INSTANCE_ID" --tags Key="ebs.csi.aws.com/cluster-name",Value="$CLUSTER_NAME"

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

echo "✓ EBS CSI Driver installed with cluster-scoped policy"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
kubectl get storageclass
