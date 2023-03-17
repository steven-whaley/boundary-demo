data "http" "boundary_cluster_auth_methods" {
  url = "${hcp_boundary_cluster.boundary-demo.cluster_url}/v1/auth-methods?scope_id=global"
}