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

variable "aws_key_name" {
  type        = string
  description = "The name of the key pair in your AWS account that you would like to add to the EC2 instances that are created"
}

variable "okta_user_password" {
  type = string
  description = "The password that will be set on the PIE, DEV, and IT Okta user accounts"
}