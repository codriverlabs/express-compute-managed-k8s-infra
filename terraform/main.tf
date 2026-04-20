locals {
  ami_arch           = var.arch == "arm64" ? "arm64" : "x86_64"
  workstation_name   = var.workstation_name != "" ? var.workstation_name : "eks-d-${var.developer_username}"
  allowed_cidrs      = var.allowed_cidr_blocks
  
  # Auto-discover VPC by tag
  vpc_filter = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.shared[0].id
  
  # Auto-calculate next available subnet index
  subnet_index = var.subnet_index != null ? var.subnet_index : local.next_available_index
  
  # Find next available subnet index by checking existing developer subnets (exclude NAT subnet at 10.0.0.0/24)
  existing_indices = [
    for s in data.aws_subnets.developer_public.ids : 
    tonumber(regex("10\\.0\\.(\\d+)\\.0/24", data.aws_subnet.existing[s].cidr_block)[0])
    if tonumber(regex("10\\.0\\.(\\d+)\\.0/24", data.aws_subnet.existing[s].cidr_block)[0]) > 0
  ]
  next_available_index = length(local.existing_indices) > 0 ? max(local.existing_indices...) + 1 : 1
  
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

  tags = { 
    Name = "eks-d-workstation-${var.developer_username}"
    "eks-cluster-name" = local.workstation_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverEKSClusterScopedPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "karpenter" {
  name = "eks-d-karpenter"
  role = aws_iam_role.workstation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "pricing:GetProducts",
          "ssm:GetParameter",
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:TerminateInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.workstation_name}" = "owned"
          }
        }
      },
      {
        Effect = "Allow"
        Action = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/kubernetes.io/cluster/${local.workstation_name}" = "owned"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.workstation.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${local.workstation_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloud_provider" {
  name = "eks-d-cloud-provider"
  role = aws_iam_role.workstation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read-only: no tag restriction needed
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerPolicies",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "iam:CreateServiceLinkedRole",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Create new EC2 resources — must be tagged with this cluster at creation time
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:CreateSecurityGroup",
          "ec2:CreateRoute",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.workstation_name}" = "owned"
          }
        }
      },
      # Mutate/delete existing EC2 resources — only those owned by this cluster
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DeleteVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteRoute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/kubernetes.io/cluster/${local.workstation_name}" = "owned"
          }
        }
      },
      # ELB write actions — only load balancers tagged with this cluster
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:AttachLoadBalancerToSubnets",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancerPolicy",
          "elasticloadbalancing:CreateLoadBalancerListeners",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancerListeners",
          "elasticloadbalancing:DetachLoadBalancerFromSubnets",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:SetLoadBalancerPoliciesOfListener"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "elasticloadbalancing:ResourceTag/kubernetes.io/cluster/${local.workstation_name}" = "owned"
          }
        }
      }
    ]
  })
}



resource "aws_iam_instance_profile" "workstation" {
  name = "eks-d-workstation-${var.developer_username}"
  role = aws_iam_role.workstation.name
}

resource "aws_security_group" "workstation" {
  name        = "eks-d-workstation-${var.developer_username}"
  description = "EKS-D workstation: SSH, Kubernetes API, kubelet, pod networking"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    description = "Kubernetes API server (worker nodes + kubectl)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.shared[0].cidr_block]
  }

  ingress {
    description = "Kubelet API (kubectl logs/exec, liveness probes)"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.shared[0].cidr_block]
  }

  ingress {
    description = "All traffic within security group (pod networking between nodes)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = local.vpc_filter
  tags   = { Name = "eks-d-workstation-${var.developer_username}" }
}

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = local.workstation_name
  message_retention_seconds = 300

  tags = {
    Name                                              = local.workstation_name
    "kubernetes.io/cluster/${local.workstation_name}" = "owned"
  }
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
              
              # Run workstation boot configuration (AMI has pre-installed components)
              cd /opt/eks-d-setup
              bash ./workstation-boot.sh "$DEVELOPER_SIGNUM" "$CLUSTER_NAME"
              EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.disk_size_gb
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name                                = local.workstation_name
    Developer                           = var.developer_username
    Arch                                = var.arch
    "kubernetes.io/cluster/eks-d"       = "owned"
    # Required by AmazonEBSCSIDriverEKSClusterScopedPolicy:
    # allows attach/detach on instances not managed by EKS (no eks:cluster-name tag)
    "ebs.csi.aws.com/cluster-name"      = local.workstation_name
  }
}
