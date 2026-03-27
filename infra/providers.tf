terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    jq = {
      source  = "massdriver-cloud/jq"
      version = "0.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_eks_cluster_auth" "main" {
  name = module.common.eks_cluster_name
}

provider "helm" {
  kubernetes = {
    cluster_ca_certificate = base64decode(module.common.eks_cluster_certificate_authority_data)
    host                   = module.common.eks_cluster_endpoint
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubernetes" {
  cluster_ca_certificate = base64decode(module.common.eks_cluster_certificate_authority_data)
  host                   = module.common.eks_cluster_endpoint
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "consul" {
  address        = "${module.common.elb.http_addr}:8501"
  scheme         = "https"
  datacenter     = "dc1"
  insecure_https = true
  token          = module.servers.consul_token
}

provider "jq" {}


provider "vault" {
  address = "https://${module.common.elb.http_addr}:8200"
  token   = trimspace(file("${path.root}/generated/vault_token"))
  # ca_cert_file    = module.common.vault_ca_crt
  skip_tls_verify = true
  tls_server_name = "demo.server.vault"
}
