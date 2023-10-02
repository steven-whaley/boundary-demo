variable "admin_pass" {
  type        = string
  description = "The password to set on the windows and linux targets for the admin user"
}

variable "region" {
  type        = string
  description = "The region to create instrastructure in"
  default     = "us-west-2"
}

variable "boundary_user" {
  type        = string
  description = "The name of the default admin user to create in HCP Boundary"
}

variable "boundary_password" {
  type        = string
  description = "The password of the default admin user to create in HCP Boundary"
}

variable "public_key" {
  type        = string
  description = "The public key to use when creating the EC2 key pair to access AWS systems"
}

variable "organization" {
    description = "The TFC Organization Name"
    type = string
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