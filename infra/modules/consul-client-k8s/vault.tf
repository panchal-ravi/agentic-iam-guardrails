locals {
  vault_jwt_auth_backend_path = "k8s_jwt"
  vault_jwt_auth_role_name    = "agent-role"
  vault_jwt_policy_name       = "agent-role-identity-policy"
}

resource "vault_jwt_auth_backend" "k8s" {
  description = "JWT auth method for EKS workloads deployed with the Consul client"
  type        = "jwt"
  path        = local.vault_jwt_auth_backend_path

  default_role       = local.vault_jwt_auth_role_name
  oidc_discovery_url = "https://${var.eks_oidc_provider}"
}

resource "vault_policy" "agent_identity" {
  name = local.vault_jwt_policy_name

  policy = <<-EOT
    path "identity/oidc/token/${local.vault_jwt_auth_role_name}" {
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

resource "vault_identity_oidc" "server" {
  issuer = "https://${var.vault_public_addr}"
}

# resource "vault_identity_oidc_provider" "default" {
#   name = "default"
#   https_enabled = true
#   issuer_host = var.vault_public_addr
# }

resource "vault_identity_oidc_role" "agent" {
  name      = local.vault_jwt_auth_role_name
  key       = "default"
  ttl       = 3600

  template = "{\"org\": \"${var.identity_claims.org}\", \"bu\": \"${var.identity_claims.bu}\", \"department\": \"${var.identity_claims.department}\", \"service_group\": \"${var.identity_claims.service_group}\", \"entity_id\": {{identity.entity.id}}, \"agent_id\": {{identity.entity.aliases.${vault_jwt_auth_backend.k8s.accessor}.name}}}"
}


