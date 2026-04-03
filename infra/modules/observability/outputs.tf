output "monitoring_namespace" {
  description = "Namespace where the observability Helm releases are installed"
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "release_names" {
  description = "Helm release names deployed by the observability module"
  value = {
    loki       = helm_release.loki.name
    prometheus = helm_release.kube_prometheus_stack.name
    promtail   = helm_release.promtail.name
  }
}
