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
