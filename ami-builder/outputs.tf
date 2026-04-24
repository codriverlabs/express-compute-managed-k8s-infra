output "ami_id" {
  description = "AMI ID stored in SSM"
  value       = "See SSM parameter: /eks-dx/ami/${var.arch}"
}

output "builder_instance_id" {
  description = "Builder EC2 instance ID"
  value       = aws_instance.builder.id
}
