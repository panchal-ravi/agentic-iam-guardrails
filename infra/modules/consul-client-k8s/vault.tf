locals {
  vault_jwt_auth_backend_path = "k8s_jwt"
  vault_jwt_auth_role_name    = "agent-role"
  vault_jwt_policy_name       = "agent-role-identity-policy"
  opa_kv_mount_path           = "opa-policies"
  opa_kv_secret_name          = "bundle"
  opa_policy_name             = "opa"
  opa_server_role_name        = "opa-server"
}

resource "vault_jwt_auth_backend" "k8s" {
  description = "JWT auth method for EKS workloads deployed with the Consul client"
  type        = "jwt"
  path        = local.vault_jwt_auth_backend_path

  default_role       = local.vault_jwt_auth_role_name
  oidc_discovery_url = "https://${var.eks_oidc_provider}"
}

resource "vault_mount" "opa_policies" {
  description = "KV v2 secrets engine for OPA policy bundles"
  path        = local.opa_kv_mount_path
  type        = "kv"
  options = {
    version = "2"
  }
}

resource "vault_kv_secret_v2" "opa_bundle" {
  mount = vault_mount.opa_policies.path
  name  = local.opa_kv_secret_name

  data_json = jsonencode({
    "code_safety.rego"      = file("${path.root}/config/opa_policies/code_safety.rego")
    "patterns.rego"         = file("${path.root}/config/opa_policies/patterns.rego")
    "pii_filter.rego"       = file("${path.root}/config/opa_policies/pii_filter.rego")
    "prompt_injection.rego" = file("${path.root}/config/opa_policies/prompt_injection.rego")
  })
}

resource "vault_policy" "agent_identity" {
  name = local.vault_jwt_policy_name

  policy = <<-EOT
    path "identity/oidc/token/${local.vault_jwt_auth_role_name}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "opa" {
  name = local.opa_policy_name

  policy = <<-EOT
    path "${local.opa_kv_mount_path}/data/${local.opa_kv_secret_name}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_jwt_auth_backend_role" "agent" {
  backend         = vault_jwt_auth_backend.k8s.path
  role_name       = local.vault_jwt_auth_role_name
  role_type       = "jwt"
  bound_audiences = ["https://kubernetes.default.svc"]

  claim_mappings = {
    "/kubernetes.io/namespace" = "namespace"
  }

  token_explicit_max_ttl  = 0
  token_period            = 1800
  token_policies          = ["default", vault_policy.agent_identity.name]
  token_type              = "service"
  user_claim              = "/kubernetes.io/pod/name"
  user_claim_json_pointer = true
}

resource "vault_jwt_auth_backend_role" "opa_server" {
  backend         = vault_jwt_auth_backend.k8s.path
  role_name       = local.opa_server_role_name
  role_type       = "jwt"
  bound_audiences = ["https://kubernetes.default.svc"]
  bound_subject   = "system:serviceaccount:opa:opa-service"

  claim_mappings = {
    "/kubernetes.io/namespace" = "namespace"
  }

  token_explicit_max_ttl  = 0
  token_period            = 1800
  token_policies          = ["default", vault_policy.opa.name]
  token_type              = "service"
  user_claim              = "sub"
  user_claim_json_pointer = true
}

resource "vault_identity_oidc" "server" {
  issuer = "https://${var.vault_public_addr}"
}

# resource "vault_identity_oidc_provider" "default" {
#   name = "default"
#   https_enabled = true
#   issuer_host = var.vault_public_addr
# }

resource "vault_identity_oidc_role" "agent" {
  name = local.vault_jwt_auth_role_name
  key  = "default"
  ttl  = 3600

  template = "{\"org\": \"${var.identity_claims.org}\", \"bu\": \"${var.identity_claims.bu}\", \"department\": \"${var.identity_claims.department}\", \"service_group\": \"${var.identity_claims.service_group}\", \"entity_id\": {{identity.entity.id}}, \"agent_id\": {{identity.entity.aliases.${vault_jwt_auth_backend.k8s.accessor}.name}}}"
}
