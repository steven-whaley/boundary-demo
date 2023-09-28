##### End of the Hashicorp Sandbox specific configuration #####
##### Platform Infrastructure Engineering Resources #####

# Create Organization Scope for Platform Engineering
resource "boundary_scope" "pie_org" {
  scope_id                 = "global"
  name                     = "pie_org"
  description              = "Platform Infrastructure Engineering Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

# Create Project for PIE AWS resources
resource "boundary_scope" "pie_aws_project" {
  name                     = "pie_aws_project"
  description              = "PIE AWS Project"
  scope_id                 = boundary_scope.pie_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_target" "pie-db-target" {
  type                     = "tcp"
  name                     = "db-target"
  description              = "Postgres Target"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 30932
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
}

resource "boundary_target" "pie-k8s-target" {
  type                     = "tcp"
  name                     = "k8s-target"
  description              = "k8s Target"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 6443
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
  brokered_credential_source_ids = [
    boundary_credential_library_vault.k8s-admin-role.id
  ]
}

resource "boundary_target" "pie-ssh-target" {
  type                     = "tcp"
  name                     = "ssh-target"
  description              = "SSH Target"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 22
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
}

# Create PIE Vault Credential Store
resource "boundary_credential_store_vault" "pie_vault" {
  name        = "PIE Vault"
  description = "PIE Vault Credential Store"
  namespace   = "admin/${vault_namespace.pie.path_fq}"
  address     = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token       = vault_token.boundary-token-pie.client_token
  scope_id    = boundary_scope.pie_aws_project.id
}

resource "boundary_credential_library_vault" "k8s-admin-role" {
  name                = "K8s Admin Role"
  description         = "K8s Credential Admin Role Token"
  credential_store_id = boundary_credential_store_vault.pie_vault.id
  path                = "kubernetes/creds/cluster-admin-role" 
  http_method         = "POST"
  http_request_body = <<EOT
  {
    "kubernetes_namespace": "default"
  }
  EOT
}