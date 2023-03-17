output "boundary_url" {
  value = hcp_boundary_cluster.boundary-demo.cluster_url
}

output "boundary_admin_auth_method" {
  value = jsondecode(data.http.boundary_cluster_auth_methods.response_body).items[0].id
}

output "vault_pub_url" {
  value = hcp_vault_cluster.boundary-vault-cluster.vault_public_endpoint_url
}

output "vault_priv_url" {
  value = hcp_vault_cluster.boundary-vault-cluster.vault_private_endpoint_url
}

output "vault_token" {
  value = hcp_vault_cluster_admin_token.boundary-token.token
  sensitive = true
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