variable "region" {
  type        = string
  description = "The region to create instrastructure in"
  default     = "us-west-2"
}

variable "boundary_password" {
    type = string
}

variable "boundary_user" {
    type = string
}

variable "okta_baseurl" {
  type = string
}

variable "okta_org_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}