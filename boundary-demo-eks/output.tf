output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "bastion_ip_address" {
  description = "Bastion host public IP"
  value       = module.bastion.public_ip
}

output "worker_ip_address" {
  description = "Boundary worker private IP"
  value       = aws_instance.worker.private_ip
}
