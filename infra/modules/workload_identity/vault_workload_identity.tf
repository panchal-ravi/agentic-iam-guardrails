locals {
  vault_auth_method_name = "nomad-workloads"
}

resource "vault_jwt_auth_backend" "nomad" {
  description = "JWT auth method for Nomad services and workloads"
  type        = "jwt"
  path        = "jwt"

  jwks_url           = "https://${var.elb.http_addr}:4646/.well-known/jwks.json"
  jwks_ca_pem        = trimspace(var.nomad_ca_crt)
  jwt_supported_algs = ["RS256", "EdDSA"]
  default_role       = "nomad-workloads"
}

resource "vault_jwt_auth_backend_role" "nomad" {
  backend         = vault_jwt_auth_backend.nomad.path
  role_name       = "nomad-workloads"
  role_type       = "jwt"
  bound_audiences = ["vault.io"]

  // use bound_claims to restrict which workload identities can authenticate with this role. 
  # bound_claims = {
  #   nomad_namespace = "default"
  #   nomad_job_id    = "mongo-query"
  # }

  user_claim              = "/extra_claims/unique_id"
  user_claim_json_pointer = "true"

  claim_mappings = {
    nomad_namespace     = "nomad_namespace"
    nomad_job_id        = "nomad_job_id"
    nomad_task          = "nomad_task"
    nomad_allocation_id = "nomad_allocation_id"
  }

  token_policies         = ["nomad-workloads", "identity-policy"]
  token_type             = "service"
  token_period           = 1800
  token_explicit_max_ttl = 0
}

resource "vault_policy" "identity_policy" {
  name = "identity-policy"

  policy = <<EOT
path "identity/oidc/token/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "identity/entity/*" {
  capabilities = ["read", "list"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOT
}

resource "vault_identity_oidc" "server" {
  issuer = "https://${var.elb.http_addr}:8200"
}

resource "vault_identity_oidc_role" "application_identity" {
  name      = "application_identity"
  key       = "default"
  client_id = var.may_act_client_id
  ttl       = 1800 # Token TTL in seconds

  # The 'template' argument defines the custom OIDC claims using HCL's heredoc syntax
  template = "{\"client_id\": \"${var.may_act_client_id}\", \"vault_entity_id\": {{identity.entity.id}}, \"agent_id\": {{identity.entity.aliases.${vault_jwt_auth_backend.nomad.accessor}.name}}}"
}


resource "vault_policy" "nomad_workloads" {
  name = "nomad-workloads"

  policy = <<EOT
path "kv/data/{{identity.entity.aliases.AUTH_METHOD_ACCESSOR.metadata.nomad_namespace}}/{{identity.entity.aliases.AUTH_METHOD_ACCESSOR.metadata.nomad_job_id}}/*" {
  capabilities = ["read"]
}

path "kv/data/{{identity.entity.aliases.AUTH_METHOD_ACCESSOR.metadata.nomad_namespace}}/{{identity.entity.aliases.AUTH_METHOD_ACCESSOR.metadata.nomad_job_id}}" {
  capabilities = ["read"]
}

path "kv/metadata/{{identity.entity.aliases.AUTH_METHOD_ACCESSOR.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}

path "kv/metadata/*" {
  capabilities = ["list"]
}
EOT
}
