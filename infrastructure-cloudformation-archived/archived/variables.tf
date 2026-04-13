variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "team_member_name" {
  description = "Team member name for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team_member_name))
    error_message = "Team member name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cluster_name" {
  description = "EKS-D cluster name"
  type        = string
  default     = ""
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for control plane"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "ssh_cidr_block" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

# Locals for computed values
locals {
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.team_member_name}-eks-d"
}
