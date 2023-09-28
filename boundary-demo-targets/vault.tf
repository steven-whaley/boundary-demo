# Create Namespaces for PIE and Dev teams
resource "vault_namespace" "pie" {
  path = "pie"
}

resource "vault_namespace" "dev" {
  path = "dev"
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

resource "vault_policy" "boundary-token-policy-pie" {
  namespace = vault_namespace.pie.path_fq
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
    path         = "${vault_mount.secrets.path}/*"
    capabilities = ["create", "update", "list", "read", "delete"]
  }
}

resource "vault_policy" "kv-access" {
  namespace = vault_namespace.pie.path_fq
  name      = "kv-access-policy"
  policy    = data.vault_policy_document.kv-access.hcl
}

# Create Token roles
# Token Role for Boundary PIE Credential Store
resource "vault_token_auth_backend_role" "boundary-token-role-pie" {
  namespace        = vault_namespace.pie.path_fq
  role_name        = "boundary-controller-role-pie"
  allowed_policies = [vault_policy.boundary-token-policy-pie.name, vault_policy.k8s-secret-policy.name]
  orphan           = true
}

resource "vault_token" "boundary-token-pie" {
  namespace = vault_namespace.pie.path_fq
  role_name = vault_token_auth_backend_role.boundary-token-role-pie.role_name
  policies  = [vault_policy.boundary-token-policy-pie.name, vault_policy.k8s-secret-policy.name]
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

# Create K8s Secrets Engine

resource "time_sleep" "wait_for_k8s" {
  depends_on      = [aws_instance.k8s_cluster]
  create_duration = "120s"
}

data "aws_s3_object" "cert" {
  depends_on = [ time_sleep.wait_for_k8s ]
  bucket = aws_s3_bucket.config_bucket.id
  key    = "ca.crt"
}

data "aws_s3_object" "vault-token" {
  depends_on = [ time_sleep.wait_for_k8s ]
  bucket = aws_s3_bucket.config_bucket.id
  key    = "vault-token"
}

resource "vault_kubernetes_secret_backend" "config" {
  namespace = vault_namespace.pie.path_fq
  path                      = "kubernetes"
  description               = "kubernetes secrets engine"
  default_lease_ttl_seconds = 600
  max_lease_ttl_seconds     = 600
  kubernetes_host           = "https://${aws_instance.k8s_cluster.private_ip}:6443"
  kubernetes_ca_cert        = data.aws_s3_object.cert.body
  service_account_jwt       = data.aws_s3_object.vault-token.body
  disable_local_ca_jwt      = false
}

resource "vault_kubernetes_secret_backend_role" "cluster_admin_role" {
  namespace = vault_namespace.pie.path_fq
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "cluster-admin-role"
  allowed_kubernetes_namespaces = ["*"]
  token_max_ttl                 = 600
  token_default_ttl             = 600
  kubernetes_role_name          = "cluster-admin"

  extra_annotations = {
    env      = "boundary demo"
  }
}

# Create KV Secrets Engine
resource "vault_mount" "secrets" {
  namespace = vault_namespace.pie.path_fq
  path        = "secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_kv_secret_backend_v2" "secrets" {
  namespace = vault_namespace.pie.path_fq
  mount                = vault_mount.secrets.path
  max_versions         = 5
  delete_version_after = 12600
  cas_required         = false
}

