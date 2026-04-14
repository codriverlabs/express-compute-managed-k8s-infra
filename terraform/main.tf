locals {
  ami_arch           = var.arch == "arm64" ? "arm64" : "x86_64"
  workstation_name   = var.workstation_name != "" ? var.workstation_name : "eks-d-${var.developer_username}"
  allowed_cidrs      = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : ["0.0.0.0/0"]
  
  # Auto-discover VPC by tag
  vpc_filter = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.shared[0].id
  
  # Auto-calculate next available subnet index
  subnet_index = var.subnet_index != null ? var.subnet_index : local.next_available_index
  
  # Find next available subnet index by checking existing subnets
  existing_indices = [
    for s in data.aws_subnets.developer_public.ids : 
    tonumber(regex("10\\.0\\.(\\d+)\\.0/24", data.aws_subnet.existing[s].cidr_block)[0])
  ]
  next_available_index = length(local.existing_indices) > 0 ? max(local.existing_indices...) + 1 : 0
  
  public_subnet_cidr  = "10.0.${local.subnet_index}.0/24"
  private_subnet_cidr = "10.0.${100 + local.subnet_index}.0/24"
}

# Auto-discover shared VPC
data "aws_vpc" "shared" {
  count = var.vpc_id == "" ? 1 : 0
  
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-shared-vpc"]
  }
}

# Find existing developer subnets to calculate next index
data "aws_subnets" "developer_public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_filter]
  }
  
  filter {
    name   = "tag:SubnetType"
    values = ["Public"]
  }
  
  filter {
    name   = "tag:Developer"
    values = ["*"]
  }
}

data "aws_subnet" "existing" {
  for_each = toset(data.aws_subnets.developer_public.ids)
  id       = each.value
}

data "aws_route_table" "public" {
  vpc_id = local.vpc_filter
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-public-rt"]
  }
}

data "aws_route_table" "private" {
  vpc_id = local.vpc_filter
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-private-rt"]
  }
}

# Developer's Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = local.vpc_filter
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.developer_username}-public-subnet"
    Developer                                       = var.developer_username
    "kubernetes.io/cluster/${local.workstation_name}" = "owned"
    "kubernetes.io/role/elb"                        = "1"
    ManagedBy                                       = "Terraform"
    SubnetType                                      = "Public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = data.aws_route_table.public.id
}

# Developer's Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = local.vpc_filter
  cidr_block        = local.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                                            = "${var.developer_username}-private-subnet"
    Developer                                       = var.developer_username
    "kubernetes.io/cluster/${local.workstation_name}" = "owned"
    "kubernetes.io/role/internal-elb"               = "1"
    ManagedBy                                       = "Terraform"
    SubnetType                                      = "Private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = data.aws_route_table.private.id
}

data "aws_availability_zones" "available" {
  state = "available"
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
  subnet_id            = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.workstation.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              export CLUSTER_NAME=${local.workstation_name}
              export DEVELOPER_SIGNUM=${var.developer_username}
              
              # Run eks-d-setup scripts (pre-installed in AMI)
              cd /opt/eks-d-setup
              
              bash ./05-prepare-etcd.sh
              bash ./06-install-eks-d.sh
              bash ./07-install-cni.sh
              bash ./08-install-coredns.sh
              bash ./09-install-ebs-csi.sh
              bash ./10-configure-node.sh
              bash ./11-install-karpenter.sh "$DEVELOPER_SIGNUM" "$CLUSTER_NAME"
              
              echo "==> Workstation ready for $DEVELOPER_SIGNUM"
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
