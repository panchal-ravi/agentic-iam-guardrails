locals {
  consul_auth_method_name = "nomad-workloads"
  tasks_role_prefix       = "nomad-tasks"
}

resource "consul_namespace" "ns" {
  name        = "ingress"
  description = "Ingress namespace for api-gateway"

  meta = {
    app = "ingress"
  }
}


resource "consul_acl_auth_method" "nomad" {
  name         = local.consul_auth_method_name
  display_name = local.consul_auth_method_name
  description  = "JWT auth method for Nomad services and workloads"
  type         = "jwt"

  config_json = jsonencode({
    JWKSURL          = "https://${var.elb.http_addr}:4646/.well-known/jwks.json"
    JWTSupportedAlgs = ["RS256"]
    JWKSCACert       = trimspace(var.nomad_ca_crt)
    BoundAudiences   = ["consul.io"]
    ClaimMappings = {
      nomad_namespace = "nomad_namespace"
      nomad_job_id    = "nomad_job_id"
      nomad_task      = "nomad_task"
      nomad_service   = "nomad_service"

      # The consul_namespace claim is only available when using Consul 
      # and Nomad Enterprise.
      consul_namespace = "consul_namespace"
    }
  })

  namespace_rule {
    bind_namespace = "$${value.consul_namespace}"
    selector       = "\"consul_namespace\" in value"
  }

  # Note: you should not set a max_token_ttl value for the auth method since
  # Consul ACL tokens cannot be renewed and Nomad expects them to live for as
  # long as the allocation runs. Nomad automatically invalidates the tokens it
  # generates when the allocation stops.
}

resource "consul_acl_binding_rule" "services" {
  auth_method = consul_acl_auth_method.nomad.name
  description = "Binding rule for services registered from Nomad"
  bind_type   = "service"

  # bind_name matches the pattern used by Nomad to register services in Consul
  # and should not be modified.
  bind_name = "$${value.nomad_service}"

  # selector ensures this binding rule is only applied to workload identities
  # for services, not tasks.
  selector = "\"nomad_service\" in value"
}

resource "consul_acl_binding_rule" "tasks" {
  auth_method = consul_acl_auth_method.nomad.name
  description = "Binding rule for Nomad tasks"
  bind_type   = "role"

  # bind_name must match the name of an ACL role to apply to tokens. You may
  # reference values from the ClaimMappings configured in the auth method to
  # make the selection more dynamic.
  #
  # Refer to Consul's documentation on claim mappings for more information.
  # https://developer.hashicorp.com/consul/docs/security/acl/auth-methods/jwt#trusted-identity-attributes-via-claim-mappings
  #   bind_name = "${local.tasks_role_prefix}-$${value.nomad_namespace}"
  bind_name = "${local.tasks_role_prefix}-ingress"

  # selector ensures this binding rule is only applied to workload identities
  # for tasks, not services.
  selector = "\"nomad_service\" not in value"
}

# consul_acl_role.tasks is the ACL role that attaches a set of policies and
# permissions to tokens.
#
# Refer to Consul's documentation on ACL roles for more information.
# https://developer.hashicorp.com/consul/docs/security/acl/acl-roles
resource "consul_acl_role" "ingress" {
  # As an example, this module creates different roles for each Nomad namespace
  # to illustrate the use of claim mappings attributes, but this can be
  # adjusted as needed in a real cluster.
  name      = "${local.tasks_role_prefix}-ingress"
  namespace = "default"

  description = "ACL role for Nomad API gateway workloads"
  policies    = [consul_acl_policy.ingress.id]
}

# consul_acl_policy.tasks is a sample ACL policy that grants tokens read access
# to Consul's service catalog and KV storage.
#
# This is the policy used in consul_acl_role.tasks if the variable
# tasks_policy_ids is not set.
# resource "consul_acl_policy" "tasks" {
#   name        = "nomad-tasks"
#   description = "ACL policy used by Nomad tasks"
#   namespace   = each.key
#   rules       = <<EOF
# key_prefix "" {
#   policy = "read"
# }

# service_prefix "" {
#   policy = "read"
# }
# EOF
# }

resource "consul_acl_policy" "ingress" {
  name        = "api-gateways"
  description = "api gateway policy"
  namespace   = "default"
  rules       = <<EOF
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

acl = "write"

agent_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "write"
}

identity_prefix "" {
  policy     = "write"
  intentions = "write"
}

key_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

mesh = "write"

query_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy     = "write"
  intentions = "write"
}
EOF
}
