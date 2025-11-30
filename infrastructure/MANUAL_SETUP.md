# Manual EKS-D Setup Guide

This guide walks through manual installation for testing before automating with user data.

## Prerequisites

- Shared VPC stack deployed
- Developer stack deployed with `EnableUserData=false`
- SSH access to control plane instance

## Step 1: Deploy Shared VPC

```bash
cd infrastructure

aws cloudformation create-stack \
  --stack-name eks-d-shared-vpc \
  --template-body file://shared-vpc-template.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=eks-d \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name eks-d-shared-vpc \
  --region us-east-1

echo "✓ Shared VPC created"
```

## Step 2: Deploy Developer Stack (Manual Mode)

```bash
# Replace values:
# - YOUR_NAME: your developer name (lowercase, hyphens only)
# - YOUR_KEY_PAIR: your EC2 key pair name
# - SUBNET_INDEX: unique number 1-50

aws cloudformation create-stack \
  --stack-name eks-d-YOUR_NAME \
  --template-body file://developer-stack-template.yaml \
  --parameters \
    ParameterKey=SharedVpcStackName,ParameterValue=eks-d-shared-vpc \
    ParameterKey=DeveloperName,ParameterValue=YOUR_NAME \
    ParameterKey=SubnetIndex,ParameterValue=1 \
    ParameterKey=KeyPairName,ParameterValue=YOUR_KEY_PAIR \
    ParameterKey=ControlPlaneInstanceType,ParameterValue=t4a.large \
    ParameterKey=EnableUserData,ParameterValue=false \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name eks-d-YOUR_NAME \
  --region us-east-1

# Get connection info
aws cloudformation describe-stacks \
  --stack-name eks-d-YOUR_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`SSHCommand`].OutputValue' \
  --output text

echo "✓ Developer stack created"
```

## Step 3: SSH to Control Plane

```bash
# Get SSH command from stack outputs
ssh -i ~/.ssh/YOUR_KEY_PAIR.pem ec2-user@ELASTIC_IP
```

## Step 4: Install Base Components

```bash
# Update system
sudo dnf update -y

# Install Docker
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Re-login or run: newgrp docker

# Verify Docker
docker --version
```

## Step 5: Install kubectl

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

## Step 6: Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

## Step 7: Prepare etcd Volume

```bash
# Format and mount etcd volume
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /var/lib/etcd
sudo mount /dev/nvme1n1 /var/lib/etcd

# Add to fstab for persistence
echo '/dev/nvme1n1 /var/lib/etcd ext4 defaults 0 2' | sudo tee -a /etc/fstab

# Verify
df -h /var/lib/etcd
```

## Step 8: Install EKS-D (kubeadm)

```bash
# Add Kubernetes repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

# Install kubeadm, kubelet, kubectl
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable kubelet

# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Initialize cluster
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

# Setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
```

## Step 9: Install CNI (Calico)

```bash
# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

# Wait for Calico pods
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n calico-system --timeout=300s

# Untaint control plane to allow scheduling
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Verify
kubectl get nodes
kubectl get pods -A
```

## Step 10: Install Karpenter 1.8.2

```bash
# Set environment variables
export CLUSTER_NAME=$(aws ssm get-parameter --name /eks-d/YOUR_NAME/cluster-name --query 'Parameter.Value' --output text)
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get IAM role ARN
export KARPENTER_IAM_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name eks-d-YOUR_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkerNodeInstanceProfile`].OutputValue' \
  --output text)

# Add Karpenter Helm repo
helm repo add karpenter https://charts.karpenter.sh
helm repo update

# Install Karpenter 1.8.2
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --version 1.8.2 \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.interruptionQueue=${CLUSTER_NAME} \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait

# Verify Karpenter installation
kubectl get pods -n karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

## Step 11: Create Karpenter NodePool

```bash
# Get subnet and security group IDs
export PRIVATE_SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name eks-d-YOUR_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' \
  --output text)

export WORKER_SG_ID=$(aws cloudformation describe-stacks \
  --stack-name eks-d-YOUR_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkerSecurityGroupId`].OutputValue' \
  --output text)

# Create EC2NodeClass
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: YOUR_NAME-eks-d-worker-node-role
  subnetSelectorTerms:
    - id: ${PRIVATE_SUBNET_ID}
  securityGroupSelectorTerms:
    - id: ${WORKER_SG_ID}
  tags:
    Developer: YOUR_NAME
    karpenter.sh/cluster: ${CLUSTER_NAME}
    ManagedBy: Karpenter
EOF

# Create NodePool
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "c"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["3"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: "100"
    memory: 100Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF

# Verify
kubectl get nodepool
kubectl get ec2nodeclass
```

## Step 12: Test Karpenter

```bash
# Deploy test workload
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.9
        resources:
          requests:
            cpu: 1
            memory: 1Gi
EOF

# Scale up to trigger Karpenter
kubectl scale deployment inflate --replicas=5

# Watch Karpenter provision nodes
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Verify worker nodes are in your subnet
kubectl get nodes -o wide

# Scale down
kubectl scale deployment inflate --replicas=0

# Watch Karpenter deprovisioning
kubectl get nodes -w
```

## Step 13: Verify Security Isolation

```bash
# Check all resources have correct tags
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=YOUR_NAME" \
  --query 'Reservations[].Instances[].[InstanceId,SubnetId,Tags[?Key==`Developer`].Value]'

# Verify instances are in your private subnet
aws ec2 describe-instances \
  --filters "Name=tag:Developer,Values=YOUR_NAME" \
  --query 'Reservations[].Instances[].[InstanceId,SubnetId]' \
  --output table

# Should match your private subnet ID
echo "Your private subnet: ${PRIVATE_SUBNET_ID}"
```

## Troubleshooting

### Karpenter not provisioning nodes

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# Check NodePool status
kubectl describe nodepool default

# Check EC2NodeClass status
kubectl describe ec2nodeclass default

# Verify IAM permissions
aws sts get-caller-identity
```

### Nodes not joining cluster

```bash
# Check kubelet logs on worker node (via Session Manager)
sudo journalctl -u kubelet -f

# Check if worker node can reach API server
curl -k https://CONTROL_PLANE_IP:6443/healthz
```

### Network issues

```bash
# Check Calico status
kubectl get pods -n calico-system

# Check pod networking
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
kubectl exec test-pod -- ping -c 3 8.8.8.8
```

## Next Steps

Once manual setup is verified:
1. Document any issues or adjustments needed
2. Update user data script with working commands
3. Redeploy with `EnableUserData=true` for automation
4. Test automated deployment

## Cleanup

```bash
# Delete test workload
kubectl delete deployment inflate

# Wait for Karpenter to deprovision nodes
kubectl get nodes -w

# Delete developer stack
aws cloudformation delete-stack --stack-name eks-d-YOUR_NAME

# After all developer stacks deleted, delete shared VPC
aws cloudformation delete-stack --stack-name eks-d-shared-vpc
```
