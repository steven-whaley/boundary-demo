data "aws_availability_zones" "available" {
  state = "available"
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

data "tfe_outputs" "boundary_demo_init" {
  organization = "swhashi"
  workspace    = "boundary-demo-init-test"
}

data "aws_arn" "peer_vpc" {
  arn = module.boundary-eks-vpc.vpc_arn
}

