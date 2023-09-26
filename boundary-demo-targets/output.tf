# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = module.eks.cluster_endpoint
# }

# output "cluster_id" {
#   description = "EKS cluster ID"
#   value       = module.eks.cluster_id
# }

output "bastion_ip_address" {
  description = "Bastion host public IP"
  value       = module.bastion.public_ip
}

output "worker_ip_address" {
  description = "Boundary worker private IP"
  value       = aws_instance.worker.private_ip
}

# output "dc_ip_address" {
#   description = "The Domain Controller IP address"
#   value = aws_instance.rdp-target.private_ip
# }

# output "it_project_id" {
#   description = "The project ID of the IT AWS project"
#   value = boundary_scope.it_aws_project.id
# }

# output "it_host_set_id" {
#   description = "The ID of the dynamic host set plugin used for the IT hosts"
#   value = boundary_host_set_plugin.it_set.id
# }