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
  description = "VPC ID for the workstation"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the workstation"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS-D cluster name"
  type        = string
  default     = "eks-d-cluster"
}
