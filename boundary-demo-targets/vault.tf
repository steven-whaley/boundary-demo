# Create Namespaces for PIE and Dev teams
resource "vault_namespace" "pie" {
  path = "pie"
}
resource "vault_namespace" "dev" {
  path = "dev"
}
resource "vault_namespace" "it" {
  path = "it"
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

# Policy for SSH target to use to access Vault Public Key for SSH certificate signing
data "vault_policy_document" "ssh-public-key-policy" {
  rule {
    path         = "${vault_mount.ssh.path}/public_key"
    capabilities = ["read", "list"]
  }
}

# Policy for retrieving a signed certificate 
data "vault_policy_document" "ssh-cert-role" {
  rule {
    path         = "${vault_mount.ssh.path}/sign/${vault_ssh_secret_backend_role.cert-role.name}"
    capabilities = ["list", "read", "create", "update"]
  }
}

# Create Policy to read Dynamic DB secrets
data "vault_policy_document" "db-secrets" {
  rule {
    path         = "${vault_database_secrets_mount.postgres.path}/creds/db1"
    capabilities = ["read"]
  }
}

#Create vault policies from policy documents
resource "vault_policy" "boundary-token-policy-dev" {
  namespace = vault_namespace.dev.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

resource "vault_policy" "boundary-token-policy-pie" {
  namespace = vault_namespace.pie.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

resource "vault_policy" "boundary-token-policy-it" {
  namespace = vault_namespace.it.path_fq
  name      = "boundary-token"
  policy    = data.vault_policy_document.boundary-token-policy.hcl
}

resource "vault_policy" "ssh-public-key-policy" {
  namespace = vault_namespace.pie.path_fq
  name      = "ssh-public-key-policy"
  policy    = data.vault_policy_document.ssh-public-key-policy.hcl
}

resource "vault_policy" "ssh-cert-role" {
  namespace = vault_namespace.pie.path_fq
  name      = "ssh-cert-role"
  policy    = data.vault_policy_document.ssh-cert-role.hcl
}

resource "vault_policy" "db-policy" {
  namespace = vault_namespace.dev.path_fq
  name      = "db-policy"
  policy    = data.vault_policy_document.db-secrets.hcl
}

# Create Tokens for Boundary to use for Credential Store
resource "vault_token_auth_backend_role" "boundary-token-role-dev" {
  namespace        = vault_namespace.dev.path_fq
  role_name        = "boundary-controller-role-dev"
  allowed_policies = [vault_policy.boundary-token-policy-dev.name, vault_policy.db-policy.name]
  orphan           = true
}

resource "vault_token_auth_backend_role" "boundary-token-role-pie" {
  namespace        = vault_namespace.pie.path_fq
  role_name        = "boundary-controller-role-pie"
  allowed_policies = [vault_policy.boundary-token-policy-pie.name, vault_policy.ssh-cert-role.name]
  orphan           = true

}

resource "vault_token_auth_backend_role" "boundary-token-role-it" {
  namespace        = vault_namespace.it.path_fq
  role_name        = "boundary-controller-role-it"
  allowed_policies = [vault_policy.boundary-token-policy-it.name]
  orphan           = true

}

resource "vault_token" "boundary-token-pie" {
  namespace = vault_namespace.pie.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-pie.role_name
  policies  = [vault_policy.boundary-token-policy-pie.name, vault_policy.ssh-cert-role.name]
  no_parent = true
  renewable = true
  ttl       = "24h"
  period    = "20m"
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

resource "vault_token" "boundary-token-it" {
  namespace = vault_namespace.it.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-it.role_name
  policies  = [vault_policy.boundary-token-policy-it.name]
  no_parent = true
  renewable = true
  ttl       = "24h"
  period    = "20m"
}

#### SSH Secrets Engine

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

#### Database Secrets Engine
# Create DB secrets mount
resource "vault_database_secrets_mount" "postgres" {
  namespace = vault_namespace.dev.path_fq
  path      = "database"

  postgresql {
    name              = "postgres"
    username          = "vault"
    password          = random_password.db_password.result
    connection_url    = "postgresql://{{username}}:{{password}}@${aws_db_instance.postgres.endpoint}/postgres"
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