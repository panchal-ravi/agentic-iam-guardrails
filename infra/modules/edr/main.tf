locals {
  chart_repository        = "https://uptycslabs.github.io/kspm-helm-charts"
  k8sosquery_chart_name   = "k8sosquery"
  k8sosquery_namespace    = "uptycs"
  k8sosquery_release_name = "k8sosquery"
  kubequery_chart_name    = "kubequery"
  kubequery_namespace     = "kubequery"
  kubequery_release_name  = "kubequery"

  kubequery_values = templatefile(var.kubequery_values_path, {
    CLUSTER_NAME = var.deployment_id
  })
}

resource "kubernetes_namespace_v1" "k8sosquery" {
  count = var.enable_k8sosquery ? 1 : 0

  metadata {
    name = local.k8sosquery_namespace
  }
}

resource "kubernetes_namespace_v1" "kubequery" {
  count = var.enable_kubequery ? 1 : 0

  metadata {
    name = local.kubequery_namespace
  }
}

resource "helm_release" "k8sosquery" {
  count = var.enable_k8sosquery ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.k8sosquery,
  ]

  atomic           = true
  chart            = local.k8sosquery_chart_name
  create_namespace = false
  name             = local.k8sosquery_release_name
  namespace        = local.k8sosquery_namespace
  repository       = local.chart_repository
  timeout          = 600
  wait             = true

  values = [
    file(var.k8sosquery_values_path),
  ]
}

resource "helm_release" "kubequery" {
  count = var.enable_kubequery ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.kubequery,
  ]

  atomic           = true
  chart            = local.kubequery_chart_name
  create_namespace = false
  name             = local.kubequery_release_name
  namespace        = local.kubequery_namespace
  repository       = local.chart_repository
  timeout          = 600
  wait             = true

  values = [
    local.kubequery_values,
  ]
}
