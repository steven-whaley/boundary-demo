terraform {
  required_providers {
    tfe = {
      version = "~> 0.49.0"
    }
  }
}

provider "tfe" {
    organization = var.organization
}