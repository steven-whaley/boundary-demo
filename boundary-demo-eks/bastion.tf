#Create EC2 bastion worker security group
module "bastion-sec-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "bastion-sec-group"
  description = "Allow SSH access and from bastion"
  vpc_id      = module.boundary-eks-vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules = ["ssh-tcp"]
  
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["ssh-tcp", "https-443-tcp","http-80-tcp","kubernetes-api-tcp"]

  egress_with_cidr_blocks = [
    {
      from_port   = 9200
      to_port     = 9202
      protocol    = "tcp"
      description = "Boundary Worker to Controller"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  name = "boundary-demo-bastion"

  ami           = data.aws_ami.aws_linux_hvm2.id
  instance_type = "t3.micro"

  key_name               = data.aws_key_pair.aws_key_name.key_name
  monitoring             = true
  subnet_id              = module.boundary-eks-vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion-sec-group.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.id
}

resource "aws_iam_role" "bastion_eks_role" {
  
  name = "bastion_eks_role"
  path = "/"

  inline_policy {
  name = "bastion_eks_policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
} 
EOF
  }

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

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion_profile"
  role = aws_iam_role.bastion_eks_role.name
}