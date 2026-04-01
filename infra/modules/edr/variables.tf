variable "deployment_id" {
  description = "Deployment identifier used as the Uptycs cluster name"
  type        = string
}

variable "enable_k8sosquery" {
  description = "Whether to install the k8sosquery Helm release"
  type        = bool
}

variable "enable_kubequery" {
  description = "Whether to install the kubequery Helm release"
  type        = bool
}

variable "k8sosquery_values_path" {
  description = "Absolute path to the k8sosquery Helm values file"
  type        = string
}

variable "kubequery_values_path" {
  description = "Absolute path to the kubequery Helm values file"
  type        = string
}
