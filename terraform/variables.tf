variable "developer_username" {
  description = "Developer username (for IAM user and tags)"
  type        = string
}

variable "workstation_name" {
  description = "Name for the workstation"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "arch" {
  description = "Architecture: x86_64 or arm64"
  type        = string
  default     = "x86_64"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 50
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the workstation"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID (optional, auto-discovered if not provided)"
  type        = string
  default     = ""
}

variable "subnet_index" {
  description = "Subnet index (0-50) - auto-calculated if not provided"
  type        = number
  default     = null
  validation {
    condition     = var.subnet_index == null || (var.subnet_index >= 0 && var.subnet_index <= 50)
    error_message = "Subnet index must be between 0 and 50"
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "eks-d"
}

variable "eks_cluster_name" {
  description = "EKS-D cluster name (deprecated, use workstation_name)"
  type        = string
  default     = ""
}
