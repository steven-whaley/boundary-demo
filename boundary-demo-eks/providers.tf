terraform {
  required_providers {
    aws = {
      version = ">= 4.0.0"
      source  = "hashicorp/aws"
    }
    hcp = {
      source = "hashicorp/hcp"
      version = "~> 0.52.0"
    }
    kubernetes = {
      version = ">= 2.0.0"
      source = "hashicorp/kubernetes"  
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "~>1.1.0"
    }
    okta = {
      source  = "okta/okta"
      version = "~> 3.40"
    }
    tfe = {
      version = "~> 0.42.0"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      name = "boundary-demo-eks"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "tfe" {}

provider "boundary" {
  addr                            = data.tfe_outputs.boundary_demo_init.values.boundary_url
  auth_method_id                  = data.tfe_outputs.boundary_demo_init.values.boundary_admin_auth_method
  password_auth_method_login_name = var.boundary_user
  password_auth_method_password   = var.boundary_password
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.zts.token
}

provider "okta" {
  org_name = var.okta_org_name
  base_url = var.okta_baseurl
}

provider "vault" {
  address = data.tfe_outputs.boundary_demo_init.values.vault_pub_url
  token   = data.tfe_outputs.boundary_demo_init.values.vault_token
  namespace = "admin"
}

provider "helm" {
  kubernetes {
    host = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data) 
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command = "aws"
    }
  }
}

provider "hcp" {}