# Create IT Namespace
resource "vault_namespace" "it" {
  path = "it"
}

# Set up LDAP secret engine for AD
resource "vault_ldap_secret_backend" "ad" {
  namespace = vault_namespace.it.path_fq
  path         = "boundary-ad"
  binddn       = "Administrator@Boundary.lab"
  bindpass     = var.admin_pass
  url          = "ldaps://${data.tfe_outputs.boundary_demo_targets.values.dc_ip_address}"
  insecure_tls = "true"
  userdn       = "CN=Users,DC=Boundary,DC=lab"
  schema       = "ad"
}

resource "vault_ldap_secret_backend_dynamic_role" "domain_admin" {
  namespace = vault_namespace.it.path_fq
  mount             = vault_ldap_secret_backend.ad.path
  role_name         = "domain_admin"
  creation_ldif     = file("${path.module}/ldifs/admin_creation.ldif")
  deletion_ldif     = file("${path.module}/ldifs/admin_deletion.ldif")
  rollback_ldif     = file("${path.module}/ldifs/admin_deletion.ldif")
  username_template = "v_admin_{{unix_time}}"
  default_ttl       = "360"
}

### Create Policies for Boundary Credential Store
#Create Policy for Boundary to manage it's own token to Vault
data "vault_policy_document" "boundary-token-policy" {
  rule {
    path         = "auth/token/lookup-self"
    capabilities = ["read"]
  }
  rule {
    path         = "auth/token/renew-self"
    capabilities = ["update"]
  }
  rule {
    path         = "auth/token/revoke-self"
    capabilities = ["update"]
  }
  rule {
    path         = "sys/leases/renew"
    capabilities = ["update"]
  }
  rule {
    path         = "sys/leases/revoke"
    capabilities = ["update"]
  }
  rule {
    path         = "sys/capabilities-self"
    capabilities = ["update"]
  }
}

data "vault_policy_document" "domain-admin-role" {
  rule {
    path         = "${vault_ldap_secret_backend.ad.path}/creds/${vault_ldap_secret_backend_dynamic_role.domain_admin.role_name}"
    capabilities = ["read"]
  }
}

resource "vault_policy" "boundary-token-policy-it" {
  namespace = vault_namespace.it.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

resource "vault_policy" "domain-admin-policy" {
  namespace = vault_namespace.it.path_fq
  name      = "domain-admin-policy"
  policy    = data.vault_policy_document.domain-admin-role.hcl
}

resource "vault_token_auth_backend_role" "boundary-token-role-it" {
  namespace        = vault_namespace.it.path_fq
  role_name        = "boundary-controller-role-it"
  allowed_policies = [vault_policy.boundary-token-policy-it.name, vault_policy.domain-admin-policy.name]
  orphan           = true
}

resource "vault_token" "boundary-token-it" {
  namespace = vault_namespace.it.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-it.role_name
  policies  = [vault_policy.boundary-token-policy-it.name, vault_policy.domain-admin-policy.name]
  no_parent = true
  renewable = true
  ttl       = "24h"
  period    = "20m"
}

# Configure Credential Store and Library in Boundary
resource "boundary_credential_store_vault" "it_vault" {
  name        = "it_vault"
  description = "IT Vault Credential Store"
  namespace   = "admin/${vault_namespace.it.path_fq}"
  address     = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token       = vault_token.boundary-token-it.client_token
  scope_id    = data.tfe_outputs.boundary_demo_targets.values.it_project_id
}

resource "boundary_credential_library_vault" "domain_admin" {
  name                = "domain_admin"
  description         = "AD Domain Admin Credentials"
  credential_store_id = boundary_credential_store_vault.it_vault.id
  path                = "${vault_ldap_secret_backend.ad.path}/creds/${vault_ldap_secret_backend_dynamic_role.domain_admin.role_name}" 
  http_method         = "GET"
  credential_type     = "username_password"
}

# Create Target
resource "boundary_target" "it-rdp-target-admin" {
  type                     = "tcp"
  name                     = "it-rdp-target-admin"
  description              = "Connect to RDP target with Vault brokered domain admin credentials"
  scope_id                 = data.tfe_outputs.boundary_demo_targets.values.it_project_id
  session_connection_limit = -1
  default_port             = 3389
  default_client_port = 53389
  host_source_ids = [
    data.tfe_outputs.boundary_demo_targets.values.it_host_set_id
  ]  
  egress_worker_filter = "\"${var.region}\" in \"/tags/region\""
  brokered_credential_source_ids = [
    boundary_credential_library_vault.domain_admin.id
  ]
}