output "boundary_url" {
  description = "The public URL of the HCP Boundary Cluster"
  value       = hcp_boundary_cluster.boundary-demo.cluster_url
}

output "boundary_admin_auth_method" {
  description = "The Auth Method ID of the default UserPass auth method in the Global scope"
  value       = jsondecode(data.http.boundary_cluster_auth_methods.response_body).items[0].id
}

output "vault_pub_url" {
  description = "The public URL of the HCP Vault cluster"
  value       = hcp_vault_cluster.boundary-vault-cluster.vault_public_endpoint_url
}

output "vault_priv_url" {
  description = "The private URL of the HCP Vault Cluster within the AWS VPC "
  value       = hcp_vault_cluster.boundary-vault-cluster.vault_private_endpoint_url
}

output "vault_token" {
  description = "The Vault admin token used to configure the Vault provider in the boundary-demo-eks workspace"
  value       = hcp_vault_cluster_admin_token.boundary-token.token
  sensitive   = true
}

output "vault_cluster_id" {
  description = "The cluster id of the HCP Vault Cluster"
  value       = hcp_vault_cluster.boundary-vault-cluster.cluster_id
}

output "hvn_id" {
  value = hcp_hvn.boundary-vault-hvn.hvn_id
}

output "hvn_self_link" {
  value = hcp_hvn.boundary-vault-hvn.self_link
}

output "hvn_cidr" {
  value = hcp_hvn.boundary-vault-hvn.cidr_block
}