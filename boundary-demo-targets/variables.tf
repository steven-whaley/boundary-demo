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