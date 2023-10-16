terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      version = "5.20.0"
      source  = "hashicorp/aws"
    }
    random = {
      version = "3.5.1"
      source = "hashicorp/random"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      name = "boundary-demo-init"
    }
  }
}

provider "aws" {
  region = var.region
}