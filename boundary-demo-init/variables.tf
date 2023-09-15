variable "boundary_user" {
  type = string
}

variable "boundary_password" {
  type = string
}

variable "region" {
  type        = string
  description = "The AWS region into which to deploy the HVN"
}