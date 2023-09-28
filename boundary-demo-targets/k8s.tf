resource "random_password" "db_password" {
  length  = 12
  special = false
}

resource "aws_instance" "k8s_cluster" {
  depends_on = [ aws_s3_bucket.config_bucket ]
  associate_public_ip_address = false
  ami = data.aws_ami.aws_linux_hvm2.id
  subnet_id = module.boundary-eks-vpc.private_subnets[0]
  instance_type = "t3.small"
  vpc_security_group_ids = [ module.k8s-sec-group.security_group_id ]
  key_name = aws_key_pair.boundary_ec2_keys.key_name
  iam_instance_profile = aws_iam_instance_profile.s3_write_profile.name
  user_data = templatefile("./k8s-cloudinit.tftpl", { password = random_password.db_password.result, bucket_name = aws_s3_bucket.config_bucket.id} )
  tags = {
    Name = "k8s-cluster"
    app = "kubernetes"
    region = "${var.region}"
  }
}

module "k8s-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name   = "k8s-sec-group"
  vpc_id = module.boundary-eks-vpc.vpc_id

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]

  ingress_cidr_blocks = [module.boundary-eks-vpc.vpc_cidr_block, data.tfe_outputs.boundary_demo_init.values.hvn_cidr]
  ingress_rules       = ["all-all"]
}