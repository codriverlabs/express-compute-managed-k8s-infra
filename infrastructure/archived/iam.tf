# IAM role for control plane EC2 instance
resource "aws_iam_role" "control_plane_role" {
  name = "${var.team_member_name}-eks-d-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.team_member_name}-eks-d-control-plane-role"
  }
}

# IAM policy for Karpenter controller
resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.team_member_name}-karpenter-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/karpenter.sh/cluster" = local.cluster_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.worker_node_role.arn
      }
    ]
  })
}

# IAM role for worker nodes
resource "aws_iam_role" "worker_node_role" {
  name = "${var.team_member_name}-eks-d-worker-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.team_member_name}-eks-d-worker-node-role"
  }
}

# Attach policies to control plane role
resource "aws_iam_role_policy_attachment" "control_plane_karpenter_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

resource "aws_iam_role_policy_attachment" "control_plane_ssm_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "control_plane_ecr_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach policies to worker node role
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "worker_cni_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "worker_ecr_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "worker_ssm_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profiles
resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "${var.team_member_name}-eks-d-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "worker_node_profile" {
  name = "${var.team_member_name}-eks-d-worker-node-profile"
  role = aws_iam_role.worker_node_role.name
}

# Service account for Karpenter
resource "aws_iam_role" "karpenter_service_account_role" {
  name = "${var.team_member_name}-karpenter-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_instance.control_plane.public_dns, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_instance.control_plane.public_dns, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
            "${replace(aws_instance.control_plane.public_dns, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_service_account_policy" {
  role       = aws_iam_role.karpenter_service_account_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

data "aws_caller_identity" "current" {}
