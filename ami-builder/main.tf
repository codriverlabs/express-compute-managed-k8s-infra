locals {
  ami_arch = var.arch == "arm64" ? "arm64" : "x86_64"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-${local.ami_arch}"]
  }
}

data "external" "current_ip" {
  program = ["bash", "-c", "curl -s https://checkip.amazonaws.com/ | python3 -c \"import sys,json; ip=sys.stdin.read().strip(); print(json.dumps({'ip': ip + '/32'}))\""]
}

resource "aws_security_group" "builder" {
  name        = "eks-d-builder-${var.arch}-${var.ami_version}"
  description = "AMI builder SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.external.current_ip.result["ip"]]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-d-builder-${var.arch}" }
}

resource "aws_instance" "builder" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.builder.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "eks-d-builder-${var.arch}" }
}

resource "null_resource" "install" {
  depends_on = [aws_instance.builder]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.key_file)
    host        = aws_instance.builder.public_ip
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "${path.module}/../eks-d-setup"
    destination = "/tmp/eks-d-setup"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "sudo bash /tmp/install.sh"
    ]
  }
}

resource "null_resource" "create_ami" {
  depends_on = [null_resource.install]

  provisioner "local-exec" {
    command = <<-EOF
      set -e
      AMI_ID=$(aws ec2 create-image \
        --instance-id ${aws_instance.builder.id} \
        --name "eks-d-${local.ami_arch}-${var.ami_version}" \
        --description "EKS-D with Karpenter - ${var.ami_version}" \
        --region ${var.aws_region} \
        --query 'ImageId' --output text)
      echo "==> Waiting for AMI $AMI_ID to become available..."
      aws ec2 wait image-available --image-ids "$AMI_ID" --region ${var.aws_region}
      aws ssm put-parameter \
        --name "/eks-d/ami/${local.ami_arch}" \
        --value "$AMI_ID" \
        --type String \
        --overwrite \
        --region ${var.aws_region}
      echo "==> AMI $AMI_ID stored at SSM: /eks-d/ami/${local.ami_arch}"
    EOF
  }
}
