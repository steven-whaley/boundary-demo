
variable "hcp_client_id" {
  description = "HCP Client ID to authenticate to HCP."
  type = string
}

variable "hcp_client_secret" {
  description = "HCP Client Secret to authenticate to HCP."
  type = string
  sensitive   = true
}

variable "tfc_org" {
  description = "Terraform Cloud Organization name."
  type = string
}

variable "workspace_name" {
  description = "Terraform Cloud Workspace name."
  type = string
}

variable "boundary_user" {
  description = "Username for the Boundary User to be created."
  type = string
}

variable "boundary_password" {
  description = "Password for the Boundary User to be created."
  type = string
}
