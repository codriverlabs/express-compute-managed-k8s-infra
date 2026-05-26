packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region"         { type = string }
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "ami_version"        { type = string }
variable "project_name" {
  type    = string
  default = "eks-dx"
}

source "amazon-ebs" "x86_64" {
  region        = var.aws_region
  instance_type = "c6a.large"

  vpc_filter {
    filters = { "tag:Name" = "${var.project_name}-shared-vpc" }
  }
  subnet_filter {
    filters   = { "tag:Type" = "NAT" }
    most_free = true
  }
  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ami_name        = "eks-dx-x86_64-${var.ami_version}"
  ami_description = "EKS-DX ${var.kubernetes_version} x86_64 - ${var.ami_version}"
  ssh_username    = "ec2-user"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  run_tags = {
    Name     = "eks-dx-builder-x86_64"
    Platform = "eks-d-xpress"
    ManagedBy = "Packer"
  }

  tags = {
    Name              = "eks-dx-x86_64-${var.ami_version}"
    Platform          = "eks-d-xpress"
    KubernetesVersion = var.kubernetes_version
    ManagedBy         = "Packer"
  }

  temporary_iam_instance_profile_policy_document {
    Version = "2012-10-17"
    Statement {
      Effect   = "Allow"
      Action   = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:CreateRepository",
        "ecr:BatchImportUpstreamImage",
        "ssm:GetParameter",
      ]
      Resource = ["*"]
    }
  }
}

source "amazon-ebs" "arm64" {
  region        = var.aws_region
  instance_type = "c6g.large"

  vpc_filter {
    filters = { "tag:Name" = "${var.project_name}-shared-vpc" }
  }
  subnet_filter {
    filters   = { "tag:Type" = "NAT" }
    most_free = true
  }
  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-arm64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ami_name        = "eks-dx-arm64-${var.ami_version}"
  ami_description = "EKS-DX ${var.kubernetes_version} arm64 - ${var.ami_version}"
  ssh_username    = "ec2-user"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  run_tags = {
    Name      = "eks-dx-builder-arm64"
    Platform  = "eks-d-xpress"
    ManagedBy = "Packer"
  }

  tags = {
    Name              = "eks-dx-arm64-${var.ami_version}"
    Platform          = "eks-d-xpress"
    KubernetesVersion = var.kubernetes_version
    ManagedBy         = "Packer"
  }

  temporary_iam_instance_profile_policy_document {
    Version = "2012-10-17"
    Statement {
      Effect   = "Allow"
      Action   = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:CreateRepository",
        "ecr:BatchImportUpstreamImage",
        "ssm:GetParameter",
      ]
      Resource = ["*"]
    }
  }
}

build {
  sources = ["source.amazon-ebs.x86_64", "source.amazon-ebs.arm64"]

  provisioner "file" {
    source      = "${path.root}/../eks-d-setup"
    destination = "/tmp/eks-d-setup"
  }

  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/tmp/scripts"
  }

  provisioner "file" {
    source      = "${path.root}/files/ecr-credential-provider-${source.name == "x86_64" ? "amd64" : "arm64"}"
    destination = "/tmp/ecr-credential-provider"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "export KUBERNETES_VERSION=${var.kubernetes_version}",
      "sudo -E bash /tmp/scripts/install.sh"
    ]
  }

  post-processor "manifest" {
    output     = "/tmp/packer-manifest.json"
    strip_path = true
  }

  post-processor "shell-local" {
    inline = [
      "python3 -c \"import json; [print(b['name']+' '+b['artifact_id'].split(':')[-1]) for b in json.load(open('/tmp/packer-manifest.json'))['builds']]\" | while read arch ami_id; do aws ssm put-parameter --name /eks-dx/ami/$arch/${var.kubernetes_version} --value $ami_id --type String --overwrite --region ${var.aws_region} && echo \"Stored /eks-dx/ami/$arch/${var.kubernetes_version} -> $ami_id\"; done"
    ]
  }
}
