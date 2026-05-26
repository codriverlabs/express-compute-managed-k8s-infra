variable "tenant_id" {
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
  description = "EC2 instance type (6th generation or newer required, e.g. m6i.xlarge, m6g.large, c6i.2xlarge)"
  type        = string
  default     = "m6a.large"
  validation {
    # Matches families like m6i, c6a, r6g, t6, x6, i6, etc. and higher (7, 8...)
    condition     = can(regex("^[a-z]+([6-9]|[1-9][0-9])[a-z]*\\.", var.instance_type))
    error_message = "instance_type must be 6th generation or newer (e.g. m6i.xlarge, c7g.large). Older generations (t3, m5, c5, etc.) are not permitted."
  }
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 20
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
  default     = "eks-dx"
}

variable "assign_elastic_ip" {
  description = "Assign Elastic IP (recommended for long-lived dev workstations, not for CI/CD)"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "EKS-D cluster name (deprecated, use workstation_name)"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS-D (e.g., 1.35, 1.36)"
  type        = string
  default     = "1.35"
}

variable "workstation_mode" {
  description = "on_demand or spot (spot enables hibernation on interruption)"
  type        = string
  default     = "on_demand"
  validation {
    condition     = contains(["on_demand", "spot"], var.workstation_mode)
    error_message = "workstation_mode must be on_demand or spot"
  }
}
