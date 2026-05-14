packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region"         { type = string }
variable "arch"               { type = string  default = "x86_64" }
variable "instance_type"      { type = string  default = "m6i.xlarge" }
variable "kubernetes_version" { type = string  default = "1.35" }
variable "ami_version"        { type = string }

locals {
  ami_arch = var.arch == "arm64" ? "arm64" : "x86_64"
}

source "amazon-ebs" "eks_dx" {
  region        = var.aws_region
  instance_type = var.instance_type

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-${local.ami_arch}"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ami_name        = "eks-dx-${local.ami_arch}-${var.ami_version}"
  ami_description = "EKS-DX with Karpenter - ${var.ami_version}"

  ssh_username = "ec2-user"

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

  run_tags = { Name = "eks-dx-builder-${var.arch}" }
}

build {
  sources = ["source.amazon-ebs.eks_dx"]

  provisioner "file" {
    source      = "${path.root}/../eks-d-setup"
    destination = "/tmp/eks-d-setup"
  }

  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/tmp/scripts"
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
      "AMI_ID=$(python3 -c \"import json; d=json.load(open('/tmp/packer-manifest.json')); print(d['builds'][-1]['artifact_id'].split(':')[-1])\")",
      "aws ssm put-parameter --name /eks-dx/ami/${local.ami_arch} --value $AMI_ID --type String --overwrite --region ${var.aws_region}",
      "echo 'AMI stored at SSM: /eks-dx/ami/${local.ami_arch} -> '$AMI_ID"
    ]
  }
}
