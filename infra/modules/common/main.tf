locals {
  key_name = "ssh_key"
}

data "aws_ami" "an_image" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["${var.owner}-consul-nomad-enterprise*"]
  }
}


data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_availability_zones" "available" {}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.deployment_id}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh.private_key_openssh
  filename = "${path.root}/generated/${local.key_name}"

  provisioner "local-exec" {
    command = "chmod 400 ${path.root}/generated/${local.key_name}"
  }
}

module "bastion_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "${var.deployment_id}-bastion"
  description = "bastion inbound sg"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = ["ssh-tcp"]
  # ingress_rules       = ["ssh-tcp", "nomad-http-tcp", "consul-webui-http-tcp", "consul-webui-https-tcp", "consul-dns-tcp", "consul-dns-udp"]
  ingress_cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "nomad_sg" {
  source      = "terraform-aws-modules/security-group/aws//modules/nomad"
  name        = "${var.deployment_id}-nomad"
  description = "nomad security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
}

module "consul_sg" {
  source      = "terraform-aws-modules/security-group/aws//modules/consul"
  name        = "${var.deployment_id}-consul"
  description = "consul security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
}

module "vault_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/vault"

  name        = "${var.deployment_id}-vault"
  description = "vault inbound"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "ssh-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
}

module "elb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.deployment_id}-elb"
  description = "Allow web traffic from internet"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["nomad-http-tcp", "vault-tcp", "consul-webui-http-tcp", "consul-webui-https-tcp", "consul-dns-tcp", "consul-dns-udp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "http_lb" {
  name                             = "${var.deployment_id}-http-lb"
  internal                         = false
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = false
  subnets                          = module.vpc.public_subnets
  security_groups                  = [module.elb_sg.security_group_id]
  tags = {
    Name = "${var.deployment_id}-http-lb"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name                 = var.deployment_id
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.owner
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
  inline_policy {
    name   = "${var.deployment_id}-metadata-access"
    policy = data.aws_iam_policy_document.metadata_access.json
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "metadata_access" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.owner
  role        = aws_iam_role.instance_role.name
}


resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.an_image.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = element(module.vpc.public_subnets, 1)
  security_groups             = [module.bastion_sg.security_group_id]
  associate_public_ip_address = true

  tags = {
    Name  = "${var.deployment_id}-bastion"
    owner = var.owner
  }

  lifecycle {
    ignore_changes = all
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_openssh
    destination = "/home/ubuntu/ssh_key"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/ssh_key",
    ]
  }

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    agent       = false
    private_key = tls_private_key.ssh.private_key_openssh
  }

}
