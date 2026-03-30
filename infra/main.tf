locals {
  deployment_id = lower("${var.owner}-${random_string.suffix.result}")
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

module "common" {
  source               = "./modules/common"
  deployment_id        = local.deployment_id
  owner                = var.owner
  vpc_cidr             = var.vpc_cidr
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  region               = var.region
  kubernetes_version   = var.kubernetes_version
  cluster_service_cidr = var.aws_eks_cluster_service_cidr
}

module "servers" {
  source               = "./modules/servers"
  deployment_id        = local.deployment_id
  owner                = var.owner
  instance_type        = var.instance_type
  private_subnets      = module.common.private_subnets
  aws_keypair_name     = module.common.aws_keypair_name
  bastion_sg_id        = module.common.bastion_sg_id
  nomad_sg_id          = module.common.nomad_sg_id
  consul_sg_id         = module.common.consul_sg_id
  vault_sg_id          = module.common.vault_sg_id
  iam_instance_profile = module.common.iam_instance_profile
  vpc_id               = module.common.vpc_id
  elb                  = module.common.elb
  bastion_ip           = module.common.bastion_ip
  ssh_key              = module.common.ssh_key
}

module "consul_client_k8s" {
  source = "./modules/consul-client-k8s"
  cluster_endpoint   = module.common.eks_cluster_endpoint
  consul_ca_crt      = module.servers.consul_ca_crt
  consul_license     = file("${path.root}/config/consul_license.hclic")
  consul_server_ip   = module.servers.server_ip
  consul_token       = module.servers.consul_token
  consul_version     = var.consul_version
  eks_oidc_provider  = module.common.eks_oidc_provider
  identity_claims    = var.identity_claims
  vault_private_addr = "https://${module.servers.server_ip}:8200"
  vault_public_addr  = "${module.common.elb.http_addr}:8200"
  depends_on = [
    module.common,
    module.servers,
  ]
}

module "clients" {
  source               = "./modules/clients"
  deployment_id        = local.deployment_id
  owner                = var.owner
  instance_type        = var.instance_type
  private_subnets      = module.common.private_subnets
  aws_keypair_name     = module.common.aws_keypair_name
  bastion_sg_id        = module.common.bastion_sg_id
  nomad_sg_id          = module.common.nomad_sg_id
  consul_sg_id         = module.common.consul_sg_id
  iam_instance_profile = module.common.iam_instance_profile
  consul_ca_crt        = module.servers.consul_ca_crt
  vault_ca_crt         = module.servers.vault_ca_crt
  connect_ca_crt       = module.servers.connect_ca_crt
  nomad_ca_cert_pem    = module.servers.nomad_ca_crt
  nomad_ca_key_pem     = module.servers.nomad_ca_key_pem
  nomad_client_count   = var.nomad_client_count
  vpc_id               = module.common.vpc_id
  elb                  = module.common.elb
}

module "workload-identity" {
  source            = "./modules/workload_identity"
  elb               = module.common.elb
  identity_claims   = var.identity_claims
  nomad_ca_crt      = module.servers.nomad_ca_crt
}
