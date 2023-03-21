###### Create Orgs and Projects #######
# Create Organization Scope for Platform Engineering
resource "boundary_scope" "pie_org" {
  scope_id                 = "global"
  name                     = "pie_org"
  description              = "Platform Infrastructure Engineering Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

# Create Project for PIE us-west-2 resources
resource "boundary_scope" "pie_w2_project" {
  name        = "pie_w2_project"
  description = "PIE AWS US-West-2 Project"
  scope_id                 = boundary_scope.pie_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create Project for PIE us-east-2 resources
resource "boundary_scope" "pie_e2_project" {
  name        = "pie_e2_project"
  description = "PIE AWS US-East-2 Project"
  scope_id                 = boundary_scope.pie_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create K8s target in Platform Engineering Project
resource "boundary_target" "prod_k8s" {
  type                     = "tcp"
  name                     = "prod_k8s"
  description              = "Prod K8s Cluster API"
  scope_id                 = boundary_scope.pie_w2_project.id
  session_connection_limit = -1
  default_port             = 443
  address = split("//", module.eks.cluster_endpoint)[1]
  egress_worker_filter = "\"us-west-2\" in \"/tags/region\""
}

# Create Organization Scope for Dev
resource "boundary_scope" "dev_org" {
  scope_id                 = "global"
  name                     = "dev_org"
  description              = "Dev Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

# Create Project for Dev us-east-2 resources
resource "boundary_scope" "dev_e2_project" {
  name        = "dev_e2_project"
  description = "Dev AWS US-East-2 Project"
  scope_id                 = boundary_scope.dev_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create Project for Dev us-west-2 resources
resource "boundary_scope" "dev_w2_project" {
  name        = "dev_w2_project"
  description = "Dev AWS US-West-2 Project"
  scope_id                 = boundary_scope.dev_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create Organization Scope for Corp IT
resource "boundary_scope" "it_org" {
  scope_id                 = "global"
  name                     = "it_org"
  description              = "Corporate IT Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

#### Create Dynamic Host Catalogs in PIE Org ####

locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

resource "time_sleep" "wait_60_sec" {
  depends_on = [aws_iam_access_key.boundary_dynamic_host_catalog]
  create_duration = "60s"
}

# Create the user to be used in Boundary for dynamic host discovery. Then attach the policy to the user.
resource "aws_iam_user" "boundary_dynamic_host_catalog" {
  name                 = "demo-${local.my_email}-bdhc"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

resource "aws_iam_user_policy" "boundary_dynamic_host_catalog" {
  user   = aws_iam_user.boundary_dynamic_host_catalog.name
  policy = data.aws_iam_policy.demo_user_permissions_boundary.policy
  name   = "DemoUserInlinePolicy"
}

# Generate some secrets to pass in to the Boundary configuration.
# WARNING: These secrets are not encrypted in the state file. Ensure that you do not commit your state file!
resource "aws_iam_access_key" "boundary_dynamic_host_catalog" {
  user = aws_iam_user.boundary_dynamic_host_catalog.name
}

# Create the dynamic host catalog for PIE 
resource "boundary_host_catalog_plugin" "pie_dynamic_catalog" {
  depends_on = [time_sleep.wait_60_sec]
  
  name        = "pie_w2_catalog"
  description = "PIE AWS us-west-2 Catalog"
  scope_id    = boundary_scope.pie_w2_project.id
  plugin_name = "aws"

  attributes_json = jsonencode({
    "region"                      = "us-west-2",
    "disable_credential_rotation" = true
  })

  secrets_json = jsonencode({
    "access_key_id"     = aws_iam_access_key.boundary_dynamic_host_catalog.id,
    "secret_access_key" = aws_iam_access_key.boundary_dynamic_host_catalog.secret
  })
}

# Create the host set for PIE team from dynamic host catalog
resource "boundary_host_set_plugin" "pie_w2_set" {
  name            = "PIE hosts in us-west-2"
  host_catalog_id = boundary_host_catalog_plugin.pie_dynamic_catalog.id
  attributes_json = jsonencode({
    "filters" = "tag:Team=PIE",
  })
}

# Create SSH Certificate target in PIE team us-west-2 project
resource "boundary_target" "pie_target" {
  type                     = "ssh"
  name                     = "ssh-cert-target"
  description              = "Target for testing SSH Certificate Auth"
  scope_id                 = boundary_scope.pie_w2_project.id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_plugin.pie_w2_set.id
    ]
  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.ssh_cert.id
  ]
  egress_worker_filter = "\"us-west-2\" in \"/tags/region\""
}

resource "boundary_target" "pie_target_tcp" {
  type                     = "tcp"
  name                     = "ssh-tcp_target"
  description              = "Target for testing SSH tcp connections"
  scope_id                 = boundary_scope.pie_w2_project.id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_plugin.pie_w2_set.id
    ]
  egress_worker_filter = "\"us-west-2\" in \"/tags/region\""
}

# Create PIE Vault Credential store
resource "boundary_credential_store_vault" "pie_vault" {
  name        = "pie_vault"
  description = "PIE Vault Credential Store"
  namespace = "admin/${vault_namespace.pie.path_fq}"
  address     = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token       = vault_token.boundary-token-pie.client_token
  scope_id    = boundary_scope.pie_w2_project.id
}

# Create SSH Cert credential library
resource "boundary_credential_library_vault_ssh_certificate" "ssh_cert" {
  name                = "ssh_cert"
  description         = "Signed SSH Certificate Credential Library"
  credential_store_id = boundary_credential_store_vault.pie_vault.id
  path                = "ssh/sign/cert-role" # change to Vault backend path
  username = "ec2-user"
  key_type = "ecdsa"
  key_bits = 384
  extensions = {
    permit-pty            = ""
  }
}

# Create Postgres RDS Target
resource "boundary_target" "dev_db" {
  type                     = "tcp"
  name                     = "dev_db"
  description              = "Dev main database"
  scope_id                 = boundary_scope.dev_w2_project.id
  session_connection_limit = -1
  default_port             = 5432
  address = split(":", aws_db_instance.postgres.endpoint)[0]
  egress_worker_filter = "\"us-west-2\" in \"/tags/region\""

  brokered_credential_source_ids = [
    boundary_credential_library_vault.database.id
  ]
}

# Create Dev Vault Credential store
resource "boundary_credential_store_vault" "dev_vault" {
  name        = "dev_vault"
  description = "Dev Vault Credential Store"
  namespace = "admin/${vault_namespace.dev.path_fq}"
  address     = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token       = vault_token.boundary-token-dev.client_token
  scope_id    = boundary_scope.dev_w2_project.id
}

# Create Database Credential Library
resource "boundary_credential_library_vault" "database" {
  name                = "database"
  description         = "Postgres DB Credential Library"
  credential_store_id = boundary_credential_store_vault.dev_vault.id
  path                = "database/creds/db1" # change to Vault backend path
  http_method         = "GET"
  credential_type = "username_password"
}