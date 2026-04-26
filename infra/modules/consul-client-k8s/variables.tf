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

variable "verify_base_url" {
  description = "IBM Verify base URL used as oidc_discovery_url and bound_issuer for the user-mcp JWT auth backend"
  type        = string
  default     = "https://verify-vault-demo.verify.ibm.com"
}

variable "postgres_admin_password" {
  description = "Password for the Postgres admin user that Vault uses to manage dynamic credentials. Demo default; rotate out-of-band in production."
  type        = string
  default     = "vault_password_123"
  sensitive   = true
}

variable "postgres_storage_class" {
  description = "Storage class for the Postgres PersistentVolumeClaim"
  type        = string
  default     = "gp2"
}

variable "postgres_storage_size" {
  description = "Size of the Postgres PersistentVolumeClaim"
  type        = string
  default     = "5Gi"
}