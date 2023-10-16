# Create EC2 key pair using public key provided in variable
resource "aws_key_pair" "boundary_ec2_keys" {
  key_name   = "boundary-enterprise-demo-ec2-key"
  public_key = var.public_key
}

# Create random password for Vault TF user
resource "random_password" "vault_pass" {
  length = 12
  special = false
}

#Create VPC and subnets for EC2 instances
module "boundary_enterprise_demo_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "boundary-enterprise-demo-vpc"
  cidr = "10.7.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.7.1.0/24", "10.7.2.0/24"]
  public_subnets  = ["10.7.11.0/24", "10.7.12.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.aws_linux_hvm2.id
  instance_type = "t3.small"

  key_name                    = aws_key_pair.boundary_ec2_keys.key_name
  monitoring                  = true
  subnet_id                   = module.boundary_enterprise_demo_vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.server-security-group.security_group_id]
  user_data                   = templatefile("./template_files/server_init.tftpl", { 
  vaultpass = random_password.vault_pass.result, 
  })

  tags = {
    Name = "boundary-enterprise-demo-server"
  }
}

module "server-security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "server-access"
  description = "Security group for Boundary and Vault server"
  vpc_id      = module.boundary_enterprise_demo_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "Connect to Vault UI/API"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Connect to Boundary UI/API"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH to Boundary/Vault server"
      cidr_blocks = "0.0.0.0/0"
    }

  ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["http-80-tcp", "https-443-tcp"]
}