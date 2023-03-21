output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "bastion_ip_address" {
  value = module.bastion.public_ip
}

output "worker_ip_address" {
  value = aws_instance.worker.private_ip
}

output "ssh_cert_ip" {
  value = aws_instance.ssh-cert-target.private_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "oidc_auth_method" {
  value = boundary_auth_method_oidc.oidc_auth_method.id
}