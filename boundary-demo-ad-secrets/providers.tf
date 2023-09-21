terraform {
  required_providers {
    aws = {
      version = "4.67.0"
      source  = "hashicorp/aws"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.9"
    }
    tfe = {
      version = "0.42.0"
    }
    vault = {
      version = "3.20.1"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      name = "boundary-demo-ad-secrets"
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