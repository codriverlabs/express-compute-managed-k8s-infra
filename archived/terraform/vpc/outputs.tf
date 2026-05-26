output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private.id
}

output "flow_log_group_name" {
  description = "VPC Flow Logs CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "launch_template_ids" {
  description = "Shared control plane launch template IDs keyed by mode-arch"
  value       = { for k, lt in aws_launch_template.control_plane : k => lt.id }
}

output "launch_template_names" {
  description = "Shared control plane launch template names keyed by mode-arch"
  value       = { for k, lt in aws_launch_template.control_plane : k => lt.name }
}
