output "workstation_id" {
  description = "EC2 instance ID"
  value       = aws_instance.workstation.id
}

output "workstation_public_ip" {
  description = "Public IP address"
  value       = aws_instance.workstation.public_ip
}

output "workstation_private_ip" {
  description = "Private IP address"
  value       = aws_instance.workstation.private_ip
}

output "iam_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.workstation.name
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.workstation.id
}
