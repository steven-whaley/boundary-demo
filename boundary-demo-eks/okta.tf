locals {
  logout_redirect_url = format("%s:%s", data.tfe_outputs.boundary_demo_init.values.boundary_url, "3000")
  callback_url        = format("%s%s", data.tfe_outputs.boundary_demo_init.values.boundary_url, "/v1/auth-methods/oidc:authenticate:callback")
}

# Create the Okta OAuth App for Boundary
resource "okta_app_oauth" "okta_app" {
  lifecycle {
    ignore_changes = [groups, response_types]
  }

  label                     = "HCP Boundary Demo"
  type                      = "web"
  login_uri                 = local.callback_url
  post_logout_redirect_uris = [local.logout_redirect_url]
  redirect_uris             = [local.callback_url]
  grant_types               = ["authorization_code"]
  groups_claim {
    type        = "FILTER"
    filter_type = "REGEX"
    name        = "groups"
    value       = ".*"
  }
}

# Create then assign the pie, dev and IT users groups to the Okta App
resource "okta_group" "pie_users" {
  name        = "pie_users"
  description = "Platform Infrastructure Engineering Group"
}

resource "okta_app_group_assignment" "pie_users" {
  app_id   = okta_app_oauth.okta_app.id
  group_id = okta_group.pie_users.id
}
resource "okta_group" "dev_users" {
  name        = "dev_users"
  description = "Developer User Group"
}

resource "okta_app_group_assignment" "dev_users" {
  app_id   = okta_app_oauth.okta_app.id
  group_id = okta_group.dev_users.id
}

resource "okta_group" "it_users" {
  name        = "it_users"
  description = "IT User Group"
}

resource "okta_app_group_assignment" "it_users" {
  app_id   = okta_app_oauth.okta_app.id
  group_id = okta_group.it_users.id
}

# Create the OIDC auth method in boundary linked to the Okta Oauth App
resource "boundary_auth_method_oidc" "oidc_auth_method" {
  name                 = "okta_auth"
  description          = "Okta OIDC Auth Method"
  scope_id             = "global"
  client_id            = okta_app_oauth.okta_app.client_id
  client_secret        = okta_app_oauth.okta_app.client_secret
  issuer               = format("%s%s.%s", "https://", var.okta_org_name, var.okta_baseurl)
  claims_scopes        = ["email", "groups", "profile"]
  signing_algorithms   = ["RS256"]
  api_url_prefix       = data.tfe_outputs.boundary_demo_init.values.boundary_url
  is_primary_for_scope = true
}

# Create the managed group in boundary for Dev users
resource "boundary_managed_group" "dev_managed_group" {
  auth_method_id = boundary_auth_method_oidc.oidc_auth_method.id
  filter         = "\"dev_users\" in \"/token/groups\""
  name           = "Dev Users Group"
}

# Create the role for dev users to connect to targets in the AWS W2 Dev project
resource "boundary_role" "okta_dev_role" {
  name          = "QA Role"
  principal_ids = [boundary_managed_group.dev_managed_group.id]
  grant_strings = [
    "id=*;type=session;actions=list,read:self,cancel:self",
    "id=*;type=target;actions=list,authorize-session,read",
    "id=*;type=host-set;actions=list,no-op",
    "id=*;type=host;actions=list,read",
    "id=*;type=host-catalog;actions=list,read",
  ]
  scope_id       = boundary_scope.dev_org.id
  grant_scope_id = boundary_scope.dev_w2_project.id
}

# Create the managed group in boundary for PIE users
resource "boundary_managed_group" "pie_managed_group" {
  auth_method_id = boundary_auth_method_oidc.oidc_auth_method.id
  filter         = "\"pie_users\" in \"/token/groups\""
  name           = "PIE Users Group"
}

# Create the role for dev users to connect to targets in the AWS W2 PIE project
resource "boundary_role" "okta_pie_role" {
  name          = "PIE Role"
  principal_ids = [boundary_managed_group.pie_managed_group.id]
  grant_strings = [
    "id=*;type=session;actions=list,read:self,cancel:self",
    "id=*;type=target;actions=list,authorize-session,read",
    "id=*;type=host-set;actions=list,no-op",
    "id=*;type=host;actions=list,read",
    "id=*;type=host-catalog;actions=list,read",
  ]
  scope_id       = boundary_scope.pie_org.id
  grant_scope_id = boundary_scope.pie_w2_project.id
}

# Create the managed group in boundary for IT users
resource "boundary_managed_group" "it_managed_group" {
  auth_method_id = boundary_auth_method_oidc.oidc_auth_method.id
  filter         = "\"it_users\" in \"/token/groups\""
  name           = "Corp Users Group"
}

# Create the role for dev users to connect to targets in the AWS W2 IT project
resource "boundary_role" "okta_it_role" {
  name          = "PIE Role"
  principal_ids = [boundary_managed_group.it_managed_group.id]
  grant_strings = [
    "id=*;type=session;actions=list,read:self,cancel:self",
    "id=*;type=target;actions=list,authorize-session,read",
    "id=*;type=host-set;actions=list,no-op",
    "id=*;type=host;actions=list,read",
    "id=*;type=host-catalog;actions=list,read",
  ]
  scope_id       = boundary_scope.it_org.id
  grant_scope_id = boundary_scope.it_w2_project.id
}
