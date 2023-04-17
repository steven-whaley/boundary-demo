locals {
  cluster_name = "boundary-demo-cluster"
  cloudinit_ssh_cert_target = {
    write_files = [
      {
        content = "TrustedUserCAKeys /etc/ssh/ca-key.pub"
        path    = "/etc/ssh/sshd_config"
        append  = true
      }
    ]
    runcmd = [
      ["curl", "-o", "/etc/ssh/ca-key.pub", "-H", "X-Vault-Token: ${vault_token.read-key.client_token}", "-H", "X-Vault-Namespace: admin/${vault_namespace.pie.path_fq}", "${data.tfe_outputs.boundary_demo_init.values.vault_priv_url}/v1/${vault_mount.ssh.path}/public_key"],
      ["chown", "1000:1000", "/etc/ssh/ca-key.pub"],
      ["chmod", "644", "/etc/ssh/ca-key.pub"],
      ["systemctl", "restart", "sshd"]
    ]
  }
}

data "cloudinit_config" "ssh_cert_target" {
  gzip          = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloudinit_ssh_cert_target)
  }
}

# Create VPC for AWS resources
module "boundary-eks-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = "boundary-demo-eks-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  public_subnets  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
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

# Create EKS Cluster boundary target
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"

  cluster_name                    = local.cluster_name
  cluster_version                 = "1.24"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  subnet_ids                      = module.boundary-eks-vpc.private_subnets
  vpc_id                          = module.boundary-eks-vpc.vpc_id

  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
  }

  cluster_security_group_additional_rules = {
    api_ingress_from_worker = {
      description              = "API Ingress from Boundary Worker"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = module.worker-sec-group.security_group_id
    }
  }

  #EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 50
    instance_types = ["t3.small"]
  }

  eks_managed_node_groups = {
    green = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Environment = "boundary-demo-eks"
  }
}

# SSH Target
resource "aws_instance" "ssh-cert-target" {
  depends_on = [
    vault_ssh_secret_backend_ca.ssh_ca, aws_vpc_peering_connection_options.dns
  ]
  lifecycle {
    ignore_changes = [user_data_base64]
  }
  ami           = data.aws_ami.aws_linux_hvm2.id
  instance_type = "t3.micro"

  key_name                    = data.aws_key_pair.aws_key_name.key_name
  monitoring                  = true
  subnet_id                   = module.boundary-eks-vpc.private_subnets[1]
  vpc_security_group_ids      = [module.ssh-cert-sec-group.security_group_id]
  user_data_base64            = data.cloudinit_config.ssh_cert_target.rendered
  user_data_replace_on_change = true

  tags = {
    Team = "PIE"
    Name = "ssh-cert-target"
  }
}

#Create SSH target security group
module "ssh-cert-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "ssh-cert-sec-group"
  description = "Allow SSH access and from bastion"
  vpc_id      = module.boundary-eks-vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.bastion-sec-group.security_group_id
    },
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.worker-sec-group.security_group_id
    },
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["https-443-tcp", "http-80-tcp"]

  egress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      cidr_blocks = data.tfe_outputs.boundary_demo_init.values.hvn_cidr
      description = "Allow Server to communicate with HCP Vault"
    }
  ]
}

#RDS Database Target
resource "aws_db_subnet_group" "postgres" {
  name       = "boundary-demo-group"
  subnet_ids = module.boundary-eks-vpc.private_subnets
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 10
  db_name                = "postgres"
  engine                 = "postgres"
  engine_version         = "12.7"
  instance_class         = "db.t3.micro"
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [module.rds-sec-group.security_group_id]
}

#RDS Security Group
module "rds-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "rds-sec-group"
  description = "Allow Access from Boundary Worker to Database endpoint"
  vpc_id      = module.boundary-eks-vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.worker-sec-group.security_group_id
    },
  ]
  ingress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      cidr_blocks = data.tfe_outputs.boundary_demo_init.values.hvn_cidr
    }
  ]
}

# Windows Target
resource "aws_instance" "rdp-target" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.micro"

  key_name               = data.aws_key_pair.aws_key_name.key_name
  monitoring             = true
  subnet_id              = module.boundary-eks-vpc.private_subnets[1]
  vpc_security_group_ids = [module.rdp-sec-group.security_group_id]

  tags = {
    Team = "IT"
    Name = "rdp-target"
  }
}

module "rdp-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "rdp-sec-group"
  description = "Allow Access from Boundary Worker to RDP target"
  vpc_id      = module.boundary-eks-vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "rdp-tcp"
      source_security_group_id = module.worker-sec-group.security_group_id
    },
  ]
}