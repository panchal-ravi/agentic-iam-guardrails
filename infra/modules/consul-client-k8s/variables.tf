variable "cluster_endpoint" {
  description = "EKS cluster endpoint used by the Consul Helm values"
  type        = string
}

variable "consul_ca_crt" {
  description = "Consul CA certificate content stored in the consul-ca-cert secret"
  type        = string
  sensitive   = true
}

variable "consul_license" {
  description = "Consul Enterprise license content stored in the consul-ent-license secret"
  type        = string
  sensitive   = true
}

variable "consul_server_ip" {
  description = "Consul server IP used by the external servers Helm configuration"
  type        = string
}

variable "consul_token" {
  description = "Consul ACL bootstrap token stored in the consul-partitions-acl-token secret"
  type        = string
  sensitive   = true
}

variable "consul_version" {
  description = "Consul Enterprise image tag rendered into the Helm values template"
  type        = string
}

variable "eks_oidc_provider" {
  description = "EKS OIDC provider host and path used to configure the Vault JWT auth backend"
  type        = string
}

variable "identity_claims" {
  description = "Custom OIDC claims added to Vault-issued workload identity tokens"
  type = object({
    org           = string
    bu            = string
    department    = string
    service_group = string
  })
}

variable "vault_private_addr" {
  description = "Vault address used by the Vault agent injector Helm values"
  type        = string
}

variable "vault_public_addr" {
  description = "Vault public address"
  type        = string
}