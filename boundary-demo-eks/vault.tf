### Create Policies for Boundary Credential Store
#Create Policy for Boundary to manage it's own token to Vault
data "vault_policy_document" "boundary-token-policy" {
    rule {
        path = "auth/token/lookup-self"
        capabilities = ["read"]
    }
    rule {
        path = "auth/token/renew-self"
        capabilities = ["update"]
    }
    rule {
        path = "auth/token/revoke-self"
        capabilities = ["update"]
    }
    rule {
        path = "sys/leases/renew"
        capabilities = ["update"]
    }
    rule {
        path = "sys/leases/revoke"
        capabilities = ["update"]
    }
    rule {
        path = "sys/capabilities-self"
        capabilities = ["update"]
    }
}

# Policy for SSH target to use to access Vault Public Key for SSH certificate signing
data "vault_policy_document" "ssh-public-key-policy" {
    rule {
        path = "${vault_mount.ssh.path}/public_key"
        capabilities = ["read", "list"]
    }
}

# Policy for retrieving a signed certificate 
data "vault_policy_document" "ssh-cert-role" {
    rule {
        path = "${vault_mount.ssh.path}/sign/${vault_ssh_secret_backend_role.cert-role.name}"
        capabilities = ["list", "read", "create", "update"]
    }
}

#Create vault policies from policy documents
resource "vault_policy" "boundary-token-policy" {
    name = "boundary-token"
    policy = data.vault_policy_document.boundary-token-policy.hcl
}

resource "vault_policy" "ssh-public-key-policy" {
    name = "ssh-public-key-policy"
    policy = data.vault_policy_document.ssh-public-key-policy.hcl
}

resource "vault_policy" "ssh-cert-role" {
    name = "ssh-cert-role"
    policy = data.vault_policy_document.ssh-cert-role.hcl
}

# Create Token for Boundary to use for Credential Store
resource "vault_token_auth_backend_role" "boundary-token-role" {
    role_name = "boundary-controller-role"
    allowed_policies = [vault_policy.boundary-token-policy.name, vault_policy.ssh-public-key-policy.name]
}

resource "vault_token" "boundary_token" {
    role_name = vault_token_auth_backend_role.boundary-token-role.namespace
    policies = [vault_policy.boundary-token-policy.name, vault_policy.ssh-cert-role.name]
    no_parent = true
    renewable = true
    ttl = "24h"
    period = "20m"
}

#Configure SSH Certificate Engine
resource "vault_mount" "ssh" {
  type = "ssh"
  path = "ssh"
}

resource "vault_ssh_secret_backend_ca" "ssh_ca" {
    backend = vault_mount.ssh.path
    generate_signing_key = true
}

# Create Token for AWS SSH Certificate Target to use to read Vault CA public key
resource "vault_token" "read-key" {
  policies = [vault_policy.ssh-public-key-policy.name]

  renewable = false
  ttl = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

resource "vault_ssh_secret_backend_role" "cert-role" {
    name          = "cert-role"
    backend       = vault_mount.ssh.path

    key_type      = "ca"
    allow_user_certificates = true
    default_extensions = {
        "permit-pty": ""
    }
    allowed_extensions = "permit-pty"
    default_user  = "ec2-user"
    allowed_users = "*"
    ttl = "30m"
    cidr_list     = "0.0.0.0/0"
}

