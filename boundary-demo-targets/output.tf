# output "bastion_ip_address" {
#   description = "Bastion host public IP"
#   value       = module.bastion.public_ip
# }

output "worker_ip_address" {
  description = "Boundary worker private IP"
  value       = aws_instance.worker.private_ip
}

output "k8s_ip_address" {
  description = "K8s host private IP"
  value       = aws_instance.k8s_cluster.private_ip
}
