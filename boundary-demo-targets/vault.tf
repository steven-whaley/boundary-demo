# Create Namespaces for PIE and Dev teams
resource "vault_namespace" "pie" {
  path = "pie"
}

resource "vault_namespace" "dev" {
  path = "dev"
}

##### Create Policies #####

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

# PIE Boundary Token Policy
resource "vault_policy" "boundary-token-policy-pie" {
  namespace = vault_namespace.pie.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

# Dev Boundary Token Policy
resource "vault_policy" "boundary-token-policy-dev" {
  namespace = vault_namespace.dev.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

# Create Policy to get K8s creds
data "vault_policy_document" "k8s-secrets" {
  rule {
    path         = "${vault_kubernetes_secret_backend.config.path}/creds/cluster-admin-role"
    capabilities = ["create", "update", "list", "read"]
  }
}

resource "vault_policy" "k8s-secret-policy" {
  namespace = vault_namespace.pie.path_fq
  name      = "k8s-secret-policy"
  policy    = data.vault_policy_document.k8s-secrets.hcl
}

# Create Policy to write to KV store
data "vault_policy_document" "kv-access" {
  rule {
    path         = "${vault_mount.secrets.path}/data/k8s-cluster"
    capabilities = ["read", "list"]
  }
}

resource "vault_policy" "kv-access" {
  namespace = vault_namespace.pie.path_fq
  name      = "kv-access-policy"
  policy    = data.vault_policy_document.kv-access.hcl
}

# Create Policy for SSH target to read Vault public key for Cert Signing
data "vault_policy_document" "ssh-public-key-policy" {
  rule {
    path         = "${vault_mount.ssh.path}/public_key"
    capabilities = ["read", "list"]
  }
}

resource "vault_policy" "ssh-public-key-policy" {
  namespace = vault_namespace.pie.path_fq
  name      = "ssh-public-key-policy"
  policy    = data.vault_policy_document.ssh-public-key-policy.hcl
}

# Policy for retrieving a signed certificate 
data "vault_policy_document" "ssh-cert-role" {
  rule {
    path         = "${vault_mount.ssh.path}/sign/${vault_ssh_secret_backend_role.cert-role.name}"
    capabilities = ["list", "read", "create", "update"]
  }
}

resource "vault_policy" "ssh-cert-role" {
  namespace = vault_namespace.pie.path_fq
  name      = "ssh-cert-role"
  policy    = data.vault_policy_document.ssh-cert-role.hcl
}

# Create Policy to read Dynamic DB secrets
data "vault_policy_document" "db-secrets" {
  rule {
    path         = "${vault_database_secrets_mount.postgres.path}/creds/db1"
    capabilities = ["read"]
  }
}

resource "vault_policy" "db-policy" {
  namespace = vault_namespace.dev.path_fq
  name      = "db-policy"
  policy    = data.vault_policy_document.db-secrets.hcl
}

##### Create Token roles and Tokens #####

# Token Role for Boundary PIE Credential Store
resource "vault_token_auth_backend_role" "boundary-token-role-pie" {
  namespace        = vault_namespace.pie.path_fq
  role_name        = "boundary-controller-role-pie"
  allowed_policies = [
    vault_policy.boundary-token-policy-pie.name, 
    vault_policy.k8s-secret-policy.name, 
    vault_policy.kv-access.name, 
    vault_policy.ssh-cert-role.name
    ]
  orphan           = true
}

resource "vault_token" "boundary-token-pie" {
  namespace = vault_namespace.pie.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-pie.role_name
  policies  = [
    vault_policy.boundary-token-policy-pie.name, 
    vault_policy.k8s-secret-policy.name, 
    vault_policy.kv-access.name,
    vault_policy.ssh-cert-role.name
    ]
  no_parent = true
  renewable = true
  ttl       = "24h"
  period    = "20m"
}

# Token Role for k8s EC2 instance to write to kv secrets engine
resource "vault_token_auth_backend_role" "k8s-role" {
  namespace        = vault_namespace.pie.path_fq
  role_name        = "k8s-role"
  allowed_policies = [vault_policy.kv-access.name]
  orphan           = true
}

resource "vault_token" "k8s-token" {
  namespace = vault_namespace.pie.path_fq
  role_name = vault_token_auth_backend_role.k8s-role.role_name
  policies  = [vault_policy.kv-access.name]
  no_parent = true
  renewable = false
  ttl       = "1h"
}

# Token Role for Dev Credential Store
resource "vault_token_auth_backend_role" "boundary-token-role-dev" {
  namespace        = vault_namespace.dev.path_fq
  role_name        = "boundary-controller-role-dev"
  allowed_policies = [vault_policy.boundary-token-policy-dev.name, vault_policy.db-policy.name]
  orphan           = true
}

resource "vault_token" "boundary-token-dev" {
  namespace = vault_namespace.dev.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-dev.role_name
  policies  = [vault_policy.boundary-token-policy-dev.name, vault_policy.db-policy.name]
  no_parent = true
  renewable = true
  ttl       = "24h"
  period    = "20m"
}

##### Create K8s Secrets Engine #####
# Get the config information we need from Parameter Store
resource "time_sleep" "wait_for_k8s" {
  depends_on      = [aws_instance.k8s_cluster]
  create_duration = "240s"
}

data "aws_ssm_parameter" "cert" {
  depends_on = [time_sleep.wait_for_k8s, aws_ssm_parameter.cert]
  name = "cert"
}

data "aws_ssm_parameter" "token" {
  depends_on = [time_sleep.wait_for_k8s, aws_ssm_parameter.token]
  name = "token"
}

# Create the backend
resource "vault_kubernetes_secret_backend" "config" {
  namespace = vault_namespace.pie.path_fq
  path                      = "kubernetes"
  description               = "kubernetes secrets engine"
  default_lease_ttl_seconds = 600
  max_lease_ttl_seconds     = 600
  kubernetes_host           = "https://${aws_instance.k8s_cluster.private_ip}:6443"
  kubernetes_ca_cert        = data.aws_ssm_parameter.cert.value
  service_account_jwt       = data.aws_ssm_parameter.token.value
  disable_local_ca_jwt      = false
}

# Create the cluster-admin role
resource "vault_kubernetes_secret_backend_role" "cluster_admin_role" {
  namespace = vault_namespace.pie.path_fq
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "cluster-admin-role"
  allowed_kubernetes_namespaces = ["*"]
  token_max_ttl                 = 600
  token_default_ttl             = 600
  kubernetes_role_type = "ClusterRole"
  kubernetes_role_name          = "cluster-admin"

  extra_annotations = {
    env      = "boundary demo"
  }
}

##### Create the KV Secrets Engine #####
# Mount the engine
resource "vault_mount" "secrets" {
  namespace = vault_namespace.pie.path_fq
  path        = "secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

# Tune the engine
resource "vault_kv_secret_backend_v2" "secrets" {
  namespace = vault_namespace.pie.path_fq
  mount                = vault_mount.secrets.path
  max_versions         = 5
  delete_version_after = 12600
  cas_required         = false
}

# Add K8s cert to KV Secrets store
resource "vault_kv_secret_v2" "k8s_ca" {
  namespace = vault_namespace.pie.path_fq
  mount = vault_mount.secrets.path
  name = "k8s-cluster"
  data_json = jsonencode(
    {
      ca_crt = data.aws_ssm_parameter.cert.value
    }
  )
}

##### Create the DB secrets engine #####

# Create DB secrets mount
resource "vault_database_secrets_mount" "postgres" {
  depends_on = [ time_sleep.wait_for_k8s, aws_instance.k8s_cluster ]
  namespace = vault_namespace.dev.path_fq
  path      = "database"

  postgresql {
    name              = "postgres"
    username          = "postgres"
    password          = random_password.db_password.result
    connection_url    = "postgresql://{{username}}:{{password}}@${aws_instance.k8s_cluster.private_ip}:30932/postgres"
    verify_connection = true
    allowed_roles     = ["db1"]
  }
}

# Create role for getting dynamic DB secrets
resource "vault_database_secret_backend_role" "db1" {
  namespace = vault_namespace.dev.path_fq
  name      = "db1"
  backend   = vault_database_secrets_mount.postgres.path
  db_name   = vault_database_secrets_mount.postgres.postgresql[0].name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
}

##### Create the SSH Cert secrets Engine #####

#Configure SSH Certificate Engine
resource "vault_mount" "ssh" {
  namespace = vault_namespace.pie.path_fq
  type      = "ssh"
  path      = "ssh"
}

resource "vault_ssh_secret_backend_ca" "ssh_ca" {
  namespace            = vault_namespace.pie.path_fq
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}

# Create Token for AWS SSH Certificate Target to use to read Vault CA public key
resource "vault_token" "read-key" {
  namespace = vault_namespace.pie.path_fq
  policies  = [vault_policy.ssh-public-key-policy.name]

  renewable = false
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

# Create Role to generate SSH certificate for credential injection into Boundary
resource "vault_ssh_secret_backend_role" "cert-role" {
  namespace = vault_namespace.pie.path_fq
  name      = "cert-role"
  backend   = vault_mount.ssh.path

  key_type                = "ca"
  allow_user_certificates = true
  default_extensions = {
    "permit-pty" : ""
  }
  allowed_extensions = "permit-pty"
  default_user       = "ec2-user"
  allowed_users      = "*"
  ttl                = "1800"
  cidr_list          = "0.0.0.0/0"
}