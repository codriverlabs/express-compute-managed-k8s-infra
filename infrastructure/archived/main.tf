terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC for the cluster
resource "aws_vpc" "eks_d_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.team_member_name}-eks-d-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "eks_d_igw" {
  vpc_id = aws_vpc.eks_d_vpc.id

  tags = {
    Name = "${var.team_member_name}-eks-d-igw"
  }
}

# Public subnet for control plane
resource "aws_subnet" "control_plane_subnet" {
  vpc_id                  = aws_vpc.eks_d_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.team_member_name}-control-plane-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets for worker nodes
resource "aws_subnet" "worker_subnets" {
  count             = 2
  vpc_id            = aws_vpc.eks_d_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.team_member_name}-worker-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_d_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_d_igw.id
  }

  tags = {
    Name = "${var.team_member_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.control_plane_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway for private subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.team_member_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.control_plane_subnet.id

  tags = {
    Name = "${var.team_member_name}-nat-gw"
  }
}

# Route table for private subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.eks_d_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.team_member_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.worker_subnets)
  subnet_id      = aws_subnet.worker_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Security group for control plane
resource "aws_security_group" "control_plane_sg" {
  name_prefix = "${var.team_member_name}-control-plane-"
  vpc_id      = aws_vpc.eks_d_vpc.id

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd
  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true
  }

  # Kubelet API
  ingress {
    from_port = 10250
    to_port   = 10250
    protocol  = "tcp"
    self      = true
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_block]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team_member_name}-control-plane-sg"
  }
}

# Security group for worker nodes
resource "aws_security_group" "worker_nodes_sg" {
  name_prefix = "${var.team_member_name}-worker-nodes-"
  vpc_id      = aws_vpc.eks_d_vpc.id

  # All traffic from control plane
  ingress {
    from_port                = 0
    to_port                  = 65535
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.control_plane_sg.id
  }

  # Node to node communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team_member_name}-worker-nodes-sg"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Control plane EC2 instance
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.control_plane_subnet.id
  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.control_plane_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  # Additional EBS volume for etcd
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_name = var.cluster_name
  }))

  tags = {
    Name = "${var.team_member_name}-eks-d-control-plane"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}
