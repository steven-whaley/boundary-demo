variable "organization" {
    description = "The TFC Organization Name"
    type = string
}

variable "boundary_user" {
  description = "The admin user to create in HCP Boundary"
  type = string
}

variable "boundary_password" {
  description = "The admin user password to set in HCP Boundary"
  type = string
}

variable "region" {
  type = string
  description = "The AWS region into which to deploy the HVN"
}

variable "okta_baseurl" {
  description = "The base url for the Okta organization used for OIDC integration. Probably okta.com"
  type        = string
}

variable "okta_org_name" {
  description = "The organization name for the Okta organization use for OIDC integration i.e. dev-32201783"
  type        = string
}

variable "okta_user_password" {
  type        = string
  description = "The password that will be set on the PIE, DEV, and IT Okta user accounts"
}

variable "admin_pass" {
  type        = string
  description = "The password to set on the windows and linux targets for the admin user"
}

variable "public_key" {
  type        = string
  description = "The public key to set in the authorized keys file in the SSH target and bastion host.  Used to log in to the hosts as ec2-user."
}

variable "aws_varset" {
  type = string
  description = "The name of the already existing varset that contains the environment variables to authenticate the AWS provider"
}

variable "OKTA_API_TOKEN" {
    type = string
  description = "The API key used to authenticate the Okta provider."
}

variable "HCP_CLIENT_ID" {
  type        = string
  description = "The HCP Client ID to authenticate the HCP provider."
}

variable "HCP_CLIENT_SECRET" {
  type        = string
  description = "The HCP Client Secret to authenticate the HCP provider"
}