output "control_plane_instance_id" {
  description = "ID of the control plane EC2 instance"
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane"
  value       = aws_instance.control_plane.private_ip
}

output "cluster_name" {
  description = "Name of the EKS-D cluster"
  value       = local.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.eks_d_vpc.id
}

output "worker_subnet_ids" {
  description = "IDs of worker node subnets"
  value       = aws_subnet.worker_subnets[*].id
}

output "worker_security_group_id" {
  description = "ID of worker nodes security group"
  value       = aws_security_group.worker_nodes_sg.id
}

output "worker_node_instance_profile" {
  description = "Instance profile for worker nodes"
  value       = aws_iam_instance_profile.worker_node_profile.name
}

output "karpenter_service_account_role_arn" {
  description = "ARN of Karpenter service account role"
  value       = aws_iam_role.karpenter_service_account_role.arn
}

output "ssh_command" {
  description = "SSH command to connect to control plane"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.control_plane.public_ip}"
}

output "kubeconfig_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${aws_instance.control_plane.public_ip}:6443"
}
