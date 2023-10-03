variable "organization" {
    description = "The TFC Organization Name"
    type = string
}

variable "admin_pass" {
  type        = string
  description = "The password to set on the windows and linux targets for the admin user"
}

variable "boundary_user" {
  type        = string
  description = "The name of the default admin user to create in HCP Boundary"
}

variable "boundary_password" {
  type        = string
  description = "The password of the default admin user to create in HCP Boundary"
}

variable "region" {
  type        = string
  description = "The AWS region into which to deploy the HVN"
}