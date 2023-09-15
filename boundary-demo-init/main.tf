resource "random_string" "random" {
  length  = 4
  special = "false"
}

#Create HCP Boundary Cluster
resource "hcp_boundary_cluster" "boundary-demo" {
  cluster_id = "demo-cluster-${random_string.random.result}"
  username   = var.boundary_user
  password   = var.boundary_password
  tier       = "PLUS"
}

resource "hcp_hvn" "boundary-vault-hvn" {
  hvn_id         = "boundary-vault-demo-hvn"
  cloud_provider = "aws"
  region         = "us-west-2"
  cidr_block     = "172.25.16.0/20"
}

resource "hcp_vault_cluster" "boundary-vault-cluster" {
  cluster_id      = "boundary-vault-cluster"
  hvn_id          = hcp_hvn.boundary-vault-hvn.hvn_id
  tier            = "dev"
  public_endpoint = true
}

resource "hcp_vault_cluster_admin_token" "boundary-token" {
  cluster_id = hcp_vault_cluster.boundary-vault-cluster.cluster_id
}