##### Set up AWS user for Boundary Dynamic Host Sets ####
##### This configuration is specific to Hashicorp AWS Sandbox accounts #####
##### If you are running this in your own AWS account with full rights to create IAM users and policies then you will want to change this ######

locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

resource "time_sleep" "wait_60_sec" {
  depends_on      = [aws_iam_access_key.boundary_dynamic_host_catalog]
  create_duration = "60s"
}

# Create the user to be used in Boundary for dynamic host discovery. Then attach the policy to the user.
resource "aws_iam_user" "boundary_dynamic_host_catalog" {
  name                 = "demo-${local.my_email}-bdhc"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

resource "aws_iam_user_policy_attachment" "boundary_dynamic_host_catalog" {
  user       = aws_iam_user.boundary_dynamic_host_catalog.name
  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}

# Generate some secrets to pass in to the Boundary configuration.
# WARNING: These secrets are not encrypted in the state file. Ensure that you do not commit your state file!
resource "aws_iam_access_key" "boundary_dynamic_host_catalog" {
  user = aws_iam_user.boundary_dynamic_host_catalog.name
}

##### End of the Hashicorp Sandbox specific configuration #####

##### PIE Org Resources #####

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

# Create targets in PIE AWS project
resource "boundary_target" "pie-k8s-target" {
  type                     = "tcp"
  name                     = "k8s-target"
  description              = "connect to the k8s Target with a token from the Vault K8s secret engine"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 6443
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
  brokered_credential_source_ids = [
    boundary_credential_library_vault.k8s-admin-role.id,
    boundary_credential_library_vault.k8s-cert.id
  ]
}

resource "boundary_target" "pie-ssh-target" {
  type                     = "tcp"
  name                     = "ssh-target"
  description              = "Connect to the SSH target with a user supplied SSH key"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 22
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
}

resource "boundary_target" "pie-ssh-cert-target" {
  type                     = "ssh"
  name                     = "pie-ssh-cert-target"
  description              = "Connect to the SSH server using OIDC username.  Only works for OIDC users."
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 22
  address = aws_instance.k8s_cluster.private_ip
  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.ssh_cert.id
  ]
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
 enable_session_recording = true
 storage_bucket_id        = boundary_storage_bucket.pie_session_recording_bucket.id
}

resource "boundary_target" "pie-ssh-cert-target-admin" {
  type                     = "ssh"
  name                     = "pie-ssh-cert-target-admin"
  description              = "Connect to the SSH target as the default ec2-user account"
  scope_id                 = boundary_scope.pie_aws_project.id
  session_connection_limit = -1
  default_port             = 22
  address = aws_instance.k8s_cluster.private_ip
  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.ssh_cert_admin.id
  ]
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""
 enable_session_recording = true
 storage_bucket_id        = boundary_storage_bucket.pie_session_recording_bucket.id
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

# Credential Library to provide K8s service token
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

# Credential Library to provide SSH certificate for logged in user
resource "boundary_credential_library_vault_ssh_certificate" "ssh_cert" {
  name                = "ssh_cert"
  description         = "Signed SSH Certificate Credential Library"
  credential_store_id = boundary_credential_store_vault.pie_vault.id
  path                = "ssh/sign/cert-role" # change to Vault backend path
  username            = "{{truncateFrom .User.Email \"@\"}}"
  key_type            = "ecdsa"
  key_bits            = 384
  extensions = {
    permit-pty = ""
  }
}

# Credential library to provide SSH certificate for ec2-user
resource "boundary_credential_library_vault_ssh_certificate" "ssh_cert_admin" {
  name                = "ssh_cert_admin"
  description         = "Signed SSH Certificate Credential Library"
  credential_store_id = boundary_credential_store_vault.pie_vault.id
  path                = "ssh/sign/cert-role" # change to Vault backend path
  username            = "ec2-user"
  key_type            = "ecdsa"
  key_bits            = 384
  extensions = {
    permit-pty = ""
  }
}

# Credential Library to provide K8s CA Certificate
resource "boundary_credential_library_vault" "k8s-cert" {
  name                = "K8s Cert"
  description         = "K8s CA Certificate"
  credential_store_id = boundary_credential_store_vault.pie_vault.id
  path                = "secrets/data/k8s-cluster" 
  http_method         = "get"
}

##### Dev Org Resources #####

# Create Organization Scope for Dev
resource "boundary_scope" "dev_org" {
  scope_id                 = "global"
  name                     = "dev_org"
  description              = "Dev Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

# Create Project for Dev AWS resources
resource "boundary_scope" "dev_aws_project" {
  name                     = "dev_aws_project"
  description              = "Dev AWS Project"
  scope_id                 = boundary_scope.dev_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create Postgres RDS Target
resource "boundary_target" "dev-db-target" {
  type                     = "tcp"
  name                     = "dev-db-target"
  description              = "Connect to the postgres database with Vault DB secrets engine credentials"
  scope_id                 = boundary_scope.dev_aws_project.id
  session_connection_limit = -1
  default_port             = 30932
  address                  = aws_instance.k8s_cluster.private_ip
  egress_worker_filter     = "\"${var.region}\" in \"/tags/region\""

  brokered_credential_source_ids = [
    boundary_credential_library_vault.database.id
  ]
}

# Create Dev Vault Credential store
resource "boundary_credential_store_vault" "dev_vault" {
  name        = "dev_vault"
  description = "Dev Vault Credential Store"
  namespace   = "admin/${vault_namespace.dev.path_fq}"
  address     = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token       = vault_token.boundary-token-dev.client_token
  scope_id    = boundary_scope.dev_aws_project.id
}

# Create Database Credential Library
resource "boundary_credential_library_vault" "database" {
  name                = "database"
  description         = "Postgres DB Credential Library"
  credential_store_id = boundary_credential_store_vault.dev_vault.id
  path                = "database/creds/db1" # change to Vault backend path
  http_method         = "GET"
  credential_type     = "username_password"
}

##### IT Org Resources #####

# Create Organization Scope for Corporate IT
resource "boundary_scope" "it_org" {
  scope_id                 = "global"
  name                     = "it_org"
  description              = "Corporate IT Org"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

# Create Project for IT AWS resources
resource "boundary_scope" "it_aws_project" {
  name                     = "it_aws_project"
  description              = "Corp IT AWS Project"
  scope_id                 = boundary_scope.it_org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

# Create the dynamic host catalog for IT 
resource "boundary_host_catalog_plugin" "it_dynamic_catalog" {
  depends_on = [time_sleep.wait_60_sec]

  name        = "it_${var.region}_catalog"
  description = "IT AWS ${var.region} Catalog"
  scope_id    = boundary_scope.it_aws_project.id
  plugin_name = "aws"

  attributes_json = jsonencode({
    "region"                      = var.region,
    "disable_credential_rotation" = true
  })

  secrets_json = jsonencode({
    "access_key_id"     = aws_iam_access_key.boundary_dynamic_host_catalog.id,
    "secret_access_key" = aws_iam_access_key.boundary_dynamic_host_catalog.secret
  })
}

# Create the host set for IT team from dynamic host catalog
resource "boundary_host_set_plugin" "it_set" {
  name            = "IT hosts in ${var.region}"
  host_catalog_id = boundary_host_catalog_plugin.it_dynamic_catalog.id
  attributes_json = jsonencode({
    "filters" = "tag:Team=IT",
  })
}

# Create the RDP Target in the IT AWS project
resource "boundary_target" "it-rdp-target" {
  type                     = "tcp"
  name                     = "it-rdp-target"
  description              = "Connect to the RDP target with user supplied credentials"
  scope_id                 = boundary_scope.it_aws_project.id
  session_connection_limit = -1
  default_port             = 3389
  default_client_port = 54389

  host_source_ids = [
    boundary_host_set_plugin.it_set.id
  ]
  egress_worker_filter = "\"${var.region}\" in \"/tags/region\""
}

# Create Session Recording Bucket
# Delay creation to give the worker time to register

resource "time_sleep" "worker_timer" {
  depends_on = [aws_instance.worker]
  create_duration = "120s"
}

resource "random_string" "bucket_string" {
  length = 4
  special = false
}

resource "boundary_storage_bucket" "pie_session_recording_bucket" {
  depends_on = [time_sleep.worker_timer]

  name        = "PIE Session Recording Bucket ${random_string.bucket_string.result}"
  description = "Session Recording bucket for PIE team"
  scope_id    = "global"
  plugin_name = "aws"
  bucket_name = aws_s3_bucket.boundary_recording_bucket.id
  attributes_json = jsonencode({
    "region"                    = var.region,
    disable_credential_rotation = true
  })

  secrets_json = jsonencode({
    "access_key_id"     = aws_iam_access_key.boundary_dynamic_host_catalog.id,
    "secret_access_key" = aws_iam_access_key.boundary_dynamic_host_catalog.secret
  })
  worker_filter = "\"${var.region}\" in \"/tags/region\""
}