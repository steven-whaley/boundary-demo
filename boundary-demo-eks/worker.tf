resource "random_uuid" "worker_uuid" {}

resource "boundary_worker" "hcp_pki_worker" {
  scope_id = "global"
  name = "boundary-worker-${random_uuid.worker_uuid.result}"
  worker_generated_auth_token = ""
}

locals {
  boundary_worker_config = <<-WORKER_CONFIG
    hcp_boundary_cluster_id = "${split(".", split("//", data.tfe_outputs.boundary_demo_init.values.boundary_url)[1])[0]}"
    listener "tcp" {
      purpose = "proxy"
      address = "0.0.0.0"
    }
    worker {
      auth_storage_path = "/etc/boundary-worker-data"
      controller_generated_activation_token = "${boundary_worker.hcp_pki_worker.controller_generated_activation_token}"
      tags {
        type = "public_instance"
        cloud = "aws"
        region = "${var.region}"
      }
    }
    WORKER_CONFIG

  cloudinit_config_boundary_worker = {
    write_files = [
      {
          content = local.boundary_worker_config
          owner = "root:root"
          path = "/run/boundary/config.hcl"
          permissions = "0644"
      },
    ]
    runcmd = [
      ["yum", "update", "-y"],
      ["yum", "install", "-y", "docker"],
      ["systemctl", "start", "docker"],
      ["docker", "run", "-p", "9202:9202", "-v", "/run/boundary:/boundary/", "hashicorp/boundary-worker-hcp", "boundary-worker", "server", "-config", "/boundary/config.hcl"]
    ]
  }
}

data "cloudinit_config" "boundary_worker" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode(local.cloudinit_config_boundary_worker)
  }
}

resource "aws_instance" "worker" {
  lifecycle {
    ignore_changes = [user_data_base64]
  }
  
  ami           = data.aws_ami.aws_linux_hvm2.id
  instance_type = "t3.micro"

  key_name               = data.aws_key_pair.sw-ec2key.key_name
  monitoring             = true
  subnet_id              = module.boundary-eks-vpc.private_subnets[0]
  vpc_security_group_ids = [module.worker-sec-group.security_group_id]
  user_data_base64       = data.cloudinit_config.boundary_worker.rendered
  user_data_replace_on_change = false

  tags = {
    Name = "boundary-worker-${random_uuid.worker_uuid.result}"
  }
}

#Create worker EC2 security group
module "worker-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "boundary-worker-sec-group"
  vpc_id      = module.boundary-eks-vpc.vpc_id

  egress_with_cidr_blocks = [
    {
      from_port = 9202
      to_port = 9202
      protocol = "tcp"
      description = "Boundary Controller to Upsream"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule = "ssh-tcp"
      cidr_blocks = module.boundary-eks-vpc.vpc_cidr_block
    },
    {
      rule = "postgresql-tcp"
      cidr_blocks = module.boundary-eks-vpc.vpc_cidr_block
    }
   ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["https-443-tcp", "http-80-tcp"]

  ingress_cidr_blocks = [module.boundary-eks-vpc.vpc_cidr_block]
  ingress_rules = ["ssh-tcp"]
}