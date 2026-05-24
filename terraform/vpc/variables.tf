variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "eks-dx"
}

variable "eks_version" {
  description = "EKS version for AL2023 AMI compatibility"
  type        = string
  default     = "1.35"
}

variable "eksd_version" {
  description = "EKS-D full version"
  type        = string
  default     = "1.35.8"
}

variable "instance_type_arm64" {
  description = "Default arm64 instance type for control plane"
  type        = string
  default     = "m7g.large"
}

variable "instance_type_x86_64" {
  description = "Default x86_64 instance type for control plane"
  type        = string
  default     = "m7i.large"
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 20
}
