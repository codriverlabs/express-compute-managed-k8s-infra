terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.project_name}-shared-vpc"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# NAT Subnet (public)
resource "aws_subnet" "nat" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-nat-subnet"
    Project = var.project_name
    Type    = "NAT"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.nat.id

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "nat_subnet" {
  subnet_id      = aws_subnet.nat.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.aws_region}/${var.project_name}-flow-logs"
  retention_in_days = 7

  tags = {
    Name    = "${var.project_name}-flow-logs"
    Project = var.project_name
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-flow-logs-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "CloudWatchLogPolicy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn

  tags = {
    Name    = "${var.project_name}-vpc-flow-log"
    Project = var.project_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Import block: handles re-deployment when Terraform state is lost.
# If the log group doesn't exist, this is a no-op.
# Removed import block - let Terraform create the log group normally
# import {
#   to = aws_cloudwatch_log_group.flow_logs
#   id = "/aws/vpc/${var.project_name}-flow-logs"
# }

# ECR Pull-Through Cache — routes public.ecr.aws pulls through private ECR
# so image layer downloads use the S3 Gateway Endpoint (free, no NAT charges)
resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  ecr_repository_prefix = "public-ecr"
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_pull_through_cache_rule" "registry_k8s_io" {
  ecr_repository_prefix = "registry-k8s-io"
  upstream_registry_url = "registry.k8s.io"
}

# S3 Gateway Endpoint — free, keeps S3 traffic inside AWS network
# Required for: ECR image pulls, EBS CSI snapshots, CloudWatch logs, Karpenter pricing data
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id,
  ]

  tags = {
    Name     = "${var.project_name}-s3-endpoint"
    Project  = var.project_name
    Platform = "eks-d-xpress"
  }
}

# ── Shared Launch Templates ───────────────────────────────────────────────────
# One spot (hibernation) + one on-demand per arch.
# AMI resolved at launch time from SSM — no update needed when AMI is rebuilt.
# Tenant-specific overrides at launch: IamInstanceProfile, SecurityGroupIds, UserData.

locals {
  lt_configs = {
    spot-arm64    = { arch = "arm64",  spot = true }
    ondemand-arm64  = { arch = "arm64",  spot = false }
    spot-x86_64   = { arch = "x86_64", spot = true }
    ondemand-x86_64 = { arch = "x86_64", spot = false }
  }
}

resource "aws_launch_template" "control_plane" {
  for_each = local.lt_configs

  name        = "${var.project_name}-${each.key}"
  description = "EKS-DX control plane — ${each.key}"

  # AMI resolved at launch time from SSM — automatically picks up new AMI builds
  image_id      = "resolve:ssm:/eks-dx/ami/${var.aws_region}/${var.eks_version}/${each.value.arch}"
  instance_type = each.value.arch == "arm64" ? var.instance_type_arm64 : var.instance_type_x86_64

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Root volume — encrypted for hibernation support
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = var.disk_size_gb
      delete_on_termination = true
      encrypted             = true
    }
  }

  # etcd volume
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      delete_on_termination = true
      encrypted             = true
    }
  }

  dynamic "instance_market_options" {
    for_each = each.value.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options { instance_interruption_behavior = "hibernate" }
    }
  }

  dynamic "hibernation_options" {
    for_each = each.value.spot ? [1] : []
    content { configured = true }
  }

  tags = {
    Name     = "${var.project_name}-${each.key}"
    Platform = "eks-d-xpress"
    Arch     = each.value.arch
    Mode     = each.value.spot ? "spot" : "on-demand"
    ManagedBy = "Terraform"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Platform  = "eks-d-xpress"
      Arch      = each.value.arch
      ManagedBy = "Karpenter"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Platform  = "eks-d-xpress"
      ManagedBy = "Terraform"
    }
  }
}
