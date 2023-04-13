terraform {
  required_version = ">= 1.0"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.52.0"
    }
  }
  cloud {
    organization = "var.tfc_org"
    workspaces {
      name = "var.workspace_name"
    }
  }
}

provider "hcp" {
  client_id     = "var.hcp_client_id"
  client_secret = "var.hcp_client_secret"
}
