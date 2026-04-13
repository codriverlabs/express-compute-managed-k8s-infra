variable "ami_version" {
  description = "Version identifier for the AMI"
  type        = string
}

variable "arch" {
  description = "Architecture: x86_64 or arm64"
  type        = string
  default     = "x86_64"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair for builder instance"
  type        = string
}

variable "key_file" {
  description = "Path to private key file"
  type        = string
}

variable "instance_type" {
  description = "Builder instance type"
  type        = string
  default     = "t3.medium"
}
