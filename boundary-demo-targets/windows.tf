# Windows Target

resource "aws_instance" "rdp-target" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.small"

  key_name               = aws_key_pair.boundary_ec2_keys.key_name
  monitoring             = true
  subnet_id              = module.boundary-eks-vpc.private_subnets[1]
  vpc_security_group_ids = [module.rdp-sec-group.security_group_id]
  user_data              = templatefile("./template_files/windows-target.tftpl", { admin_pass = var.admin_pass })
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

  ingress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "Allow ingress from everything in HVN VPC for Vault Connectivity"
      cidr_blocks = data.tfe_outputs.boundary_demo_init.values.hvn_cidr
    }
  ]
}
