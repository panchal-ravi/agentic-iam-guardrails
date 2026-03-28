locals {
  chart_repository               = "https://helm.releases.hashicorp.com"
  consul_chart_name              = "consul"
  consul_namespace               = "consul"
  consul_release_name            = "dc1-default"
  vault_agent_injector_chart     = "vault"
  vault_agent_injector_name      = "vault-agent-injector"
  vault_agent_injector_namespace = "vault"
}

resource "kubernetes_namespace_v1" "consul" {
  metadata {
    name = local.consul_namespace
  }
}

resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = local.vault_agent_injector_namespace
  }
}

resource "kubernetes_secret_v1" "consul_ca_cert" {
  metadata {
    name      = "consul-ca-cert"
    namespace = kubernetes_namespace_v1.consul.metadata[0].name
  }

  data = {
    "tls.crt" = var.consul_ca_crt
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "consul_partitions_acl_token" {
  metadata {
    name      = "consul-partitions-acl-token"
    namespace = kubernetes_namespace_v1.consul.metadata[0].name
  }

  data = {
    token = var.consul_token
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "consul_ent_license" {
  metadata {
    name      = "consul-ent-license"
    namespace = kubernetes_namespace_v1.consul.metadata[0].name
  }

  data = {
    key = var.consul_license
  }

  type = "Opaque"
}

resource "helm_release" "consul" {
  depends_on = [
    kubernetes_secret_v1.consul_ca_cert,
    kubernetes_secret_v1.consul_ent_license,
    kubernetes_secret_v1.consul_partitions_acl_token,
  ]

  atomic           = true
  chart            = local.consul_chart_name
  create_namespace = false
  name             = local.consul_release_name
  namespace        = kubernetes_namespace_v1.consul.metadata[0].name
  repository       = local.chart_repository
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.root}/config/consul-client-helm-template.yaml", {
      cluster_endpoint = var.cluster_endpoint
      consul_server_ip = var.consul_server_ip
      consul_version   = var.consul_version
    })
  ]
}

resource "helm_release" "vault_agent_injector" {
  depends_on = [
    kubernetes_namespace_v1.vault,
  ]

  atomic           = true
  chart            = local.vault_agent_injector_chart
  create_namespace = false
  name             = local.vault_agent_injector_name
  namespace        = kubernetes_namespace_v1.vault.metadata[0].name
  repository       = local.chart_repository
  timeout          = 600
  wait             = true

  values = [
    templatefile("${path.root}/config/vault-agent-injector-helm-template.yaml", {
      vault_addr = var.vault_private_addr
    })
  ]
}
