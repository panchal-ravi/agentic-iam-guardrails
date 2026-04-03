locals {
  loki_chart_repository       = "https://grafana.github.io/helm-charts"
  prometheus_chart_repository = "https://prometheus-community.github.io/helm-charts"
  promtail_chart_repository   = "https://grafana.github.io/helm-charts"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

resource "helm_release" "loki" {
  depends_on = [
    kubernetes_namespace_v1.monitoring,
  ]

  atomic           = true
  chart            = "loki"
  create_namespace = false
  name             = var.loki_release_name
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository       = local.loki_chart_repository
  timeout          = 600
  version          = var.loki_chart_version
  wait             = true

  values = [
    file(var.loki_values_path),
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.loki,
  ]

  atomic           = true
  chart            = "kube-prometheus-stack"
  create_namespace = false
  name             = var.prometheus_release_name
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository       = local.prometheus_chart_repository
  timeout          = 600
  version          = var.prometheus_chart_version
  wait             = true

  values = [
    file(var.prometheus_values_path),
  ]
}

resource "helm_release" "promtail" {
  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.loki,
  ]

  atomic           = true
  chart            = "promtail"
  create_namespace = false
  name             = var.promtail_release_name
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository       = local.promtail_chart_repository
  reset_values     = true
  timeout          = 600
  version          = var.promtail_chart_version
  wait             = true

  values = [
    file(var.promtail_values_path),
  ]
}
