variable "loki_chart_version" {
  description = "Helm chart version for the Loki release"
  type        = string
  default     = "6.55.0"
}

variable "loki_release_name" {
  description = "Helm release name for Loki"
  type        = string
  default     = "loki"
}

variable "loki_values_path" {
  description = "Absolute path to the Loki Helm values file"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace used for the observability stack"
  type        = string
  default     = "monitoring"
}

variable "prometheus_chart_version" {
  description = "Helm chart version for kube-prometheus-stack"
  type        = string
  default     = "82.15.0"
}

variable "prometheus_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "prometheus_values_path" {
  description = "Absolute path to the kube-prometheus-stack Helm values file"
  type        = string
}

variable "promtail_chart_version" {
  description = "Helm chart version for the Promtail release"
  type        = string
  default     = "6.17.1"
}

variable "promtail_release_name" {
  description = "Helm release name for Promtail"
  type        = string
  default     = "promtail"
}

variable "promtail_values_path" {
  description = "Absolute path to the Promtail Helm values file"
  type        = string
}
