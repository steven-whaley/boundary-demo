# Get the default userpass auth method ID from the HCP cluster
data "http" "boundary_cluster_auth_methods" {
  url = "${hcp_boundary_cluster.boundary-demo.cluster_url}/v1/auth-methods?filter=%22password%22+in+%22%2Fitem%2Ftype%22&scope_id=global"
}