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

output "subnet_index" {
  description = "Allocated subnet index"
  value       = local.subnet_index
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "Public subnet CIDR"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "private_subnet_cidr" {
  description = "Private subnet CIDR"
  value       = aws_subnet.private.cidr_block
}

output "iam_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.workstation.name
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.workstation.id
}

output "karpenter_interruption_queue" {
  description = "Karpenter interruption SQS queue URL"
  value       = aws_sqs_queue.karpenter_interruption.url
}
