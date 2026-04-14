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
              
              # Karpenter v1.10.0 (latest stable)
              export KARPENTER_VERSION=v1.10.0
              export CLUSTER_NAME=${var.eks_cluster_name}
              
              # Initialize EKS-D (if not already running)
              if ! systemctl is-active --quiet eks-d; then
                  echo "EKS-D not running, initializing..."
              fi
              
              # Install Karpenter via Helm
              helm repo add karpenter https://charts.karpenter.sh
              helm repo update
              helm upgrade --install karpenter karpenter/karpenter \
                --namespace karpenter \
                --create-namespace \
                --version "${KARPENTER_VERSION}" \
                --set settings.clusterName=${var.eks_cluster_name} \
                --set serviceAccount.create=true \
                --set controller.resources.requests.cpu=1 \
                --set controller.resources.requests.memory=1Gi
              
              echo "==> Workstation ready for ${var.developer_username}"
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
