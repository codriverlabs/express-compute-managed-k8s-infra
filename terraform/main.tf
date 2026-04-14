terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  ami_arch           = var.arch == "arm64" ? "arm64" : "x86_64"
  workstation_name   = var.workstation_name != "" ? var.workstation_name : "eks-d-${var.developer_username}"
  allowed_cidrs      = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : ["0.0.0.0/0"]
}

data "aws_ssm_parameter" "workstation_ami" {
  name = "/eks-d/ami/${local.ami_arch}"
}

data "aws_iam_user" "developer" {
  user_name = var.developer_username
}

data "external" "developer_policies" {
  program = ["bash", "-c",
    "aws iam list-attached-user-policies --user-name '${var.developer_username}' --query '{arns: join(`\",\"`, AttachedPolicies[].PolicyArn)}' --output json | python3 -c \"import sys,json; d=json.load(sys.stdin); print(json.dumps({'arns': d.get('arns') or ''}))\""]
}

resource "aws_iam_role" "workstation" {
  name = "eks-d-workstation-${var.developer_username}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "eks-d-workstation-${var.developer_username}" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "developer_policies" {
  for_each   = toset(split(",", data.external.developer_policies.result["arns"]))
  role       = aws_iam_role.workstation.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "workstation" {
  name = "eks-d-workstation-${var.developer_username}"
  role = aws_iam_role.workstation.name
}

resource "aws_security_group" "workstation" {
  name        = "eks-d-workstation-${var.developer_username}"
  description = "EKS-D workstation: SSH, Karpenter"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = var.vpc_id
  tags   = { Name = "eks-d-workstation-${var.developer_username}" }
}

resource "aws_instance" "workstation" {
  ami                  = data.aws_ssm_parameter.workstation_ami.value
  instance_type        = var.instance_type
  key_name             = var.key_pair_name != "" ? var.key_pair_name : null
  iam_instance_profile = aws_iam_instance_profile.workstation.name
  subnet_id            = var.subnet_id
  vpc_security_group_ids = [aws_security_group.workstation.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              export CLUSTER_NAME=${var.eks_cluster_name}
              export DEVELOPER_USERNAME=${var.developer_username}
              
              # =============================================================================
              # Step 1: Prepare etcd volume (if exists)
              # =============================================================================
              if [ -b /dev/nvme1n1 ]; then
                echo "==> Preparing etcd volume..."
                sudo mkfs.ext4 -F /dev/nvme1n1
                sudo mkdir -p /var/lib/etcd
                sudo mount /dev/nvme1n1 /var/lib/etcd
                echo '/dev/nvme1n1 /var/lib/etcd ext4 defaults 0 2' | sudo tee -a /etc/fstab
              fi
              
              # =============================================================================
              # Step 2: Initialize EKS-D cluster (using pre-installed binaries)
              # =============================================================================
              echo "==> Initializing EKS-D cluster..."
              PRIVATE_IP=$(hostname -I | awk '{print $1}')
              
              sudo kubeadm init \
                --pod-network-cidr=192.168.0.0/16 \
                --service-cidr=10.96.0.0/12 \
                --apiserver-advertise-address=${PRIVATE_IP}
              
              # Setup kubeconfig
              mkdir -p $HOME/.kube
              sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              sudo chown $(id -u):$(id -g) $HOME/.kube/config
              
              # =============================================================================
              # Step 3: Install AWS VPC CNI
              # =============================================================================
              echo "==> Installing AWS VPC CNI..."
              kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.20.4/config/master/aws-k8s-cni.yaml
              kubectl wait --for=condition=ready pod -l k8s-app=aws-node -n kube-system --timeout=300s
              
              # =============================================================================
              # Step 4: Install CoreDNS
              # =============================================================================
              echo "==> Installing CoreDNS..."
              kubectl apply -f https://github.com/kubernetes/kubernetes/raw/release-1.29/cluster/addons/dns/coredns.yaml
              kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=300s
              
              # =============================================================================
              # Step 5: Install EBS CSI Driver
              # =============================================================================
              echo "==> Installing EBS CSI Driver..."
              kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.53"
              kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s
              
              # Default storage class
              cat <<STORAGE | kubectl apply -f -
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
              STORAGE
              
              # =============================================================================
              # Step 6: Untaint control plane (allow workloads on control plane)
              # =============================================================================
              echo "==> Untainting control plane..."
              kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
              kubectl taint nodes --all node-role.kubernetes.io/master- || true
              
              # =============================================================================
              # Step 7: Install Karpenter v1.10.0
              # =============================================================================
              echo "==> Installing Karpenter..."
              helm repo add karpenter https://charts.karpenter.sh
              helm repo update
              helm upgrade --install karpenter karpenter/karpenter \
                --namespace karpenter \
                --create-namespace \
                --version "v1.10.0" \
                --set settings.clusterName=${CLUSTER_NAME} \
                --set serviceAccount.create=true \
                --set controller.resources.requests.cpu=1 \
                --set controller.resources.requests.memory=1Gi
              
              # =============================================================================
              # Done
              # =============================================================================
              echo "==> Workstation ready for ${DEVELOPER_USERNAME}"
              kubectl get nodes
              kubectl get pods -A
              EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.disk_size_gb
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name      = local.workstation_name
    Developer = var.developer_username
    Arch      = var.arch
  }
}
