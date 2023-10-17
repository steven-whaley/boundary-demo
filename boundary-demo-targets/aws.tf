# Create EC2 key pair using public key provided in variable
resource "aws_key_pair" "boundary_ec2_keys" {
  key_name   = "boundary-demo-ec2-key"
  public_key = var.public_key
}

# Create VPC for AWS resources
module "boundary-eks-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = "boundary-demo-eks-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  public_subnets  = ["10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
 
}

### Create peering connection to Vault HVN 
resource "hcp_aws_network_peering" "vault" {
  hvn_id          = data.tfe_outputs.boundary_demo_init.values.hvn_id
  peering_id      = "boundary-demo-cluster"
  peer_vpc_id     = module.boundary-eks-vpc.vpc_id
  peer_account_id = module.boundary-eks-vpc.vpc_owner_id
  peer_vpc_region = data.aws_arn.peer_vpc.region
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
  auto_accept               = true
}

resource "time_sleep" "wait_60s" {
  depends_on = [
    aws_vpc_peering_connection_accepter.peer
  ]
  create_duration = "60s"
}

resource "aws_vpc_peering_connection_options" "dns" {
  depends_on = [
    time_sleep.wait_60s
  ]
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "hcp_hvn_route" "hcp_vault" {
  hvn_link         = data.tfe_outputs.boundary_demo_init.values.hvn_self_link
  hvn_route_id     = "vault-to-internal-clients"
  destination_cidr = module.boundary-eks-vpc.vpc_cidr_block
  target_link      = hcp_aws_network_peering.vault.self_link
}

resource "aws_route" "vault" {
  # for_each = toset(module.boundary-vpc.private_route_table_ids)
  for_each = {
    for idx, rt_id in module.boundary-eks-vpc.private_route_table_ids : idx => rt_id
  }
  route_table_id            = each.value
  destination_cidr_block    = data.tfe_outputs.boundary_demo_init.values.hvn_cidr
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
}

resource "aws_iam_instance_profile" "ssm_write_profile" {
  name = "ssm-write-profile"
  role = aws_iam_role.ssm_write_role.name
}

data "aws_iam_policy_document" "ssm_write_policy" {
  statement {
    effect = "Allow"
    actions = ["ssm:PutParameter"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "boundary-demo-ssm-policy"
  description = "Policy used in Boundary demo to kube info to SSM"
  policy      = data.aws_iam_policy_document.ssm_write_policy.json
}

resource "aws_iam_role" "ssm_write_role" {
  
  name = "ssm_write_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com"
                ]
            }
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "ssm_write_policy" {
  name = "boundary-demo-ssm-policy-attachment"
  roles = [aws_iam_role.ssm_write_role.name]
  policy_arn = aws_iam_policy.ssm_policy.arn
}

# Create Parameter store entries so that TF can delete them on teardown

resource "aws_ssm_parameter" "cert" {
  lifecycle {
    ignore_changes = [ value ]
  }
  name  = "cert"
  type  = "String"
  value = "placeholder"
}

resource "aws_ssm_parameter" "token" {
  lifecycle {
    ignore_changes = [ value ]
  }
  name  = "token"
  type  = "String"
  value = "placeholder"
}

# Create bucket for session recording
resource "random_string" "boundary_bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "boundary_recording_bucket" {
  bucket        = "boundary-recording-bucket-${random_string.boundary_bucket_suffix.result}"
  force_destroy = true
}