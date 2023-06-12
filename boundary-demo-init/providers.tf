terraform {
  required_version = ">= 1.0"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.52.0"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      name = "boundary-demo-init"
    }
  }
}

provider "hcp" {}
