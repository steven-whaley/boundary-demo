terraform {
  required_providers {
    aws = {
      version = "4.67.0"
      source  = "hashicorp/aws"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.52.0"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.9"
    }
    tfe = {
      version = "0.42.0"
    }
    vault = {
      version = "3.14.0"
    }
    okta = {
      source  = "okta/okta"
      version = "3.46.0"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      name = "boundary-demo-targets"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "tfe" {}

provider "boundary" {
  addr                   = data.tfe_outputs.boundary_demo_init.values.boundary_url
  auth_method_id         = data.tfe_outputs.boundary_demo_init.values.boundary_admin_auth_method
  auth_method_login_name = var.boundary_user
  auth_method_password   = var.boundary_password
}

provider "vault" {
  address   = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token     = data.tfe_outputs.boundary_demo_init.values.vault_token
  namespace = "admin"
}

provider "hcp" {}