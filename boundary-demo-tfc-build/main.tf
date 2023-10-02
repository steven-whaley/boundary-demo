# Create a project to hold the workspaces

resource "tfe_project" "boundary_demo_project" {
  organization = var.organization
  name = "Boundary Demo Project"
}

# Create the workspaces
resource "tfe_workspace" "boundary_demo_init" {
  name           = "boundary-demo-init"
  description = "Workspace to create HCP Boundary and Vault clusters"
  execution_mode = "remote"
  remote_state_consumer_ids = [tfe_workspace.boundary_demo_targets.id, tfe_workspace.boundary_demo_ad_secrets.id]
  assessments_enabled = false
  project_id = tfe_project.boundary_demo_project.id
}

resource "tfe_workspace" "boundary_demo_targets" {
  name           = "boundary-demo-targets"
  description = "Workspace to create Boundary Config and Targets in AWS"
  execution_mode = "remote"
  remote_state_consumer_ids = [tfe_workspace.boundary_demo_ad_secrets.id]
  assessments_enabled = false
  project_id = tfe_project.boundary_demo_project.id
}

resource "tfe_workspace" "boundary_demo_ad_secrets" {
  name           = "boundary-demo-ad-secrets"
  description = "Workspace to create set up the AD secrets engine for use with the RDP target"
  execution_mode = "remote"
  assessments_enabled = false
  project_id = tfe_project.boundary_demo_project.id
}

# Create a variable set for all of the project related variables
resource "tfe_variable_set" "boundary_demo_varset" {
    name = "Boundary Demo Varset"
    description = "Variable set for variables in Boundary Demo Project workspaces"
}

# Add variable to the variable set
resource "tfe_variable" "boundary_user" {
  key             = "boundary_user"
  value           = var.boundary_user
  category        = "terraform"
  description = "The admin user to create in HCP Boundary"
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "boundary_password" {
  key             = "boundary_password"
  value           = var.boundary_password
  category        = "terraform"
  sensitive = true
  description = "The admin user password to create for HCP Boundary"
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "region" {
  key             = "region"
  value           = var.region
  category        = "terraform"
  description = "The AWS region in which to deploy resources"
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "okta_baseurl" {
  key             = "okta_baseurl"
  value           = var.okta_baseurl
  category        = "terraform"
  description = "The base url for the Okta organization used for OIDC integration. Probably okta.com"
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "okta_org_name" {
  key             = "okta_org_name"
  value           = var.okta_org_name
  category        = "terraform"
  description = "The organization name for the Okta organization use for OIDC integration i.e. dev-32201783"
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "okta_user_password" {
  key             = "okta_user_password"
  value           = var.okta_user_password
  category        = "terraform"
  description = "The password that will be set on the PIE, DEV, and IT Okta user accounts"
  sensitive = true
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "admin_pass" {
  key             = "admin_pass"
  value           = var.admin_pass
  category        = "terraform"
  description = "The password that will be set windows and linux targets"
  sensitive = true
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "public_key" {
  key             = "public_key"
  value           = var.public_key
  category        = "terraform"
  description = "The public key to set in the authorized keys file in the SSH target and bastion host.  Used to log in to the hosts as ec2-user."
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "organization" {
  key             = "organization"
  value           = var.organization
  category        = "terraform"
  description = "The TFCB Organization that is being used to deploy this demo."
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "OKTA_API_TOKEN" {
  key             = "OKTA_API_TOKEN"
  value           = var.OKTA_API_TOKEN
  category        = "env"
  description = "The API key to use to interact with Okta."
  sensitive = true
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "HCP_CLIENT_ID" {
  key             = "HCP_CLIENT_ID"
  value           = var.HCP_CLIENT_ID
  category        = "env"
  description = "The HCP Client ID."
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

resource "tfe_variable" "HCP_CLIENT_SECRET" {
  key             = "HCP_CLIENT_SECRET"
  value           = var.HCP_CLIENT_SECRET
  category        = "env"
  description = "The HCP Client Secret."
  sensitive = true
  variable_set_id = tfe_variable_set.boundary_demo_varset.id
}

#Attach the variable set to all workspaces in the project
resource "tfe_project_variable_set" "boundary_demo_varset" {
    variable_set_id = tfe_variable_set.boundary_demo_varset.id
    project_id = tfe_project.boundary_demo_project.id
}

# Get information on the variable set that contains the AWS credentials
data "tfe_variable_set" "aws_varset" {
    name = var.aws_varset
    organization = var.organization
}

# Add the varset with AWS credentials to the project
resource "tfe_project_variable_set" "aws_varset" {
    variable_set_id = data.tfe_variable_set.aws_varset.id
    project_id = tfe_project.boundary_demo_project.id
}