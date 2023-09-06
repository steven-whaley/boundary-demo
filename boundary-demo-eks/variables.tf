variable "region" {
  type        = string
  description = "The region to create instrastructure in"
  default     = "us-west-2"
}

variable "boundary_password" {
  description = "The Boundary admin user that will be set in the provider"
  type        = string
}

variable "boundary_user" {
  description = "The Boundary admin user password that will be set in the provider"
  type        = string
}

variable "okta_baseurl" {
  description = "The base url for the Okta organization used for OIDC integration. Probably okta.com"
  type        = string
}

variable "okta_org_name" {
  description = "The organization name for the Okta organization use for OIDC integration i.e. dev-32201783"
  type        = string
}

variable "db_user" {
  description = "The username to set on the Postgres database Boundary target"
  type        = string
}

variable "db_password" {
  description = "The password to set on the Postgres database Boundary target"
  type        = string
}

variable "okta_user_password" {
  type = string
  description = "The password that will be set on the PIE, DEV, and IT Okta user accounts"
}

variable "admin_pass" {
  type = string
  description = "The password to set on the windows and linux targets for the admin user"
}

variable "public_key" {
  type = string
  description = "The public key to set in the authorized keys file in the SSH target and bastion host.  Used to log in to the hosts as ec2-user."
}