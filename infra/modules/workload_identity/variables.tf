variable "elb" {}
variable "identity_claims" {
  description = "Custom OIDC claims added to Vault-issued workload identity tokens"
  type = object({
    org           = string
    bu            = string
    department    = string
    service_group = string
  })
}
variable "nomad_ca_crt" {}
