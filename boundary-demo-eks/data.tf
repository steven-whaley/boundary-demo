data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "zts" {
  name = module.eks.cluster_id
}

data "aws_ami" "aws_linux_hvm2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_key_pair" "aws_key_name" {
  key_name = var.aws_key_name
}

data "tfe_outputs" "boundary_demo_init" {
  organization = var.tfc_org
  workspace    = var.init_workspace_name
}

data "aws_arn" "peer_vpc" {
  arn = module.boundary-eks-vpc.vpc_arn
}

##### These data sources are used to create the IAM user for Dynamic Host Sets.  They may not be necessary if building outside of Hashicorp SE Sandbox accounts #####
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy" "demo_user_permissions_boundary" {
  name = "DemoUser"
}
##### End of Hashicorp specific Sandbox account data sources #####
