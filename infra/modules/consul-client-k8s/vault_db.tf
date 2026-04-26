locals {
  user_mcp_jwt_auth_path  = "jwt-user-mcp"
  user_mcp_db_mount_path  = "database"
  user_mcp_db_conn_name   = "users-db"
  user_mcp_read_db_role   = "user-mcp-read-role"
  user_mcp_write_db_role  = "user-mcp-write-role"
  user_mcp_read_jwt_role  = "user-mcp-read"
  user_mcp_write_jwt_role = "user-mcp-write"
  user_mcp_read_policy    = "user-mcp-db-read"
  user_mcp_write_policy   = "user-mcp-db-write"
  user_mcp_audience       = "user-mcp"

  # IBM Verify exposes its OIDC discovery document at
  # {tenant}/oauth2/.well-known/openid-configuration; the issuer claim in
  # tokens it mints is {tenant}/oauth2. var.verify_base_url is the bare
  # tenant URL (e.g. https://verify-vault-demo.verify.ibm.com).
  verify_oidc_issuer = "${trimsuffix(var.verify_base_url, "/")}/oauth2"

  postgres_internal_host = kubernetes_service_v1.postgres_internal_lb.status[0].load_balancer[0].ingress[0].hostname
  users_db_connection_url = format(
    "postgresql://{{username}}:{{password}}@%s:5432/%s?sslmode=disable",
    local.postgres_internal_host,
    local.users_db_name,
  )

  user_mcp_read_creation_stmt = <<-SQL
    CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
    GRANT CONNECT ON DATABASE ${local.users_db_name} TO "{{name}}";
    GRANT USAGE ON SCHEMA public TO "{{name}}";
    GRANT SELECT ON users TO "{{name}}";
  SQL

  user_mcp_write_creation_stmt = <<-SQL
    CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
    GRANT CONNECT ON DATABASE ${local.users_db_name} TO "{{name/}}";
    GRANT USAGE ON SCHEMA public TO "{{name}}";
    GRANT SELECT, INSERT, UPDATE, DELETE ON users TO "{{name}}";
    GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO "{{name}}";
  SQL

  user_mcp_revocation_stmt = <<-SQL
    REVOKE ALL PRIVILEGES ON users FROM "{{name}}";
    REVOKE ALL PRIVILEGES ON SCHEMA public FROM "{{name}}";
    REVOKE CONNECT ON DATABASE ${local.users_db_name} FROM "{{name}}";
    DROP ROLE IF EXISTS "{{name}}";
  SQL
}

resource "vault_mount" "database" {
  path        = local.user_mcp_db_mount_path
  type        = "database"
  description = "Database secrets engine for user-mcp dynamic Postgres credentials"
}

# Vault (running on EC2 outside the cluster) reaches Postgres via the
# internal NLB. The NLB hostname is published as soon as AWS provisions
# the load balancer, but DNS propagation and target-group registration
# take additional time. This Job runs `pg_isready` from inside the
# cluster against the NLB hostname and only completes once Postgres
# answers — gating creation of the Vault DB connection on a fully usable
# endpoint, not just a published name.
resource "kubernetes_job_v1" "postgres_nlb_ready" {
  depends_on = [
    kubernetes_service_v1.postgres_internal_lb,
    kubernetes_stateful_set_v1.postgres,
  ]

  metadata {
    name      = "postgres-nlb-ready-${substr(sha256(local.postgres_internal_host), 0, 10)}"
    namespace = local.postgres_namespace
  }

  spec {
    backoff_limit = 0

    template {
      metadata {
        labels = {
          app = "postgres-nlb-ready"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name    = "probe"
          image   = "postgres:16"
          command = ["/bin/sh", "-c"]

          args = [<<-SH
            set -eu
            HOST=${local.postgres_internal_host}
            PORT=5432
            echo "Probing $HOST:$PORT (DNS + TCP + Postgres handshake)..."
            for i in $(seq 1 90); do
              if pg_isready -h "$HOST" -p "$PORT" -t 5 >/dev/null 2>&1; then
                echo "NLB ready after $i attempt(s)"
                exit 0
              fi
              echo "  attempt $i: not ready yet"
              sleep 10
            done
            echo "ERROR: NLB $HOST:$PORT not ready after 15 minutes" >&2
            exit 1
          SH
          ]
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "20m"
  }
}

resource "vault_database_secret_backend_connection" "users_db" {
  backend       = vault_mount.database.path
  name          = local.user_mcp_db_conn_name
  allowed_roles = [local.user_mcp_read_db_role, local.user_mcp_write_db_role]

  postgresql {
    connection_url = local.users_db_connection_url
    username       = local.postgres_admin_user
    password       = var.postgres_admin_password
  }

  depends_on = [
    kubernetes_job_v1.users_schema_seed,
    kubernetes_job_v1.postgres_nlb_ready,
  ]
}

resource "vault_database_secret_backend_role" "user_mcp_read" {
  backend     = vault_mount.database.path
  name        = local.user_mcp_read_db_role
  db_name     = vault_database_secret_backend_connection.users_db.name
  default_ttl = 3600
  max_ttl     = 86400

  creation_statements   = [local.user_mcp_read_creation_stmt]
  revocation_statements = [local.user_mcp_revocation_stmt]
}

resource "vault_database_secret_backend_role" "user_mcp_write" {
  backend     = vault_mount.database.path
  name        = local.user_mcp_write_db_role
  db_name     = vault_database_secret_backend_connection.users_db.name
  default_ttl = 3600
  max_ttl     = 86400

  creation_statements   = [local.user_mcp_write_creation_stmt]
  revocation_statements = [local.user_mcp_revocation_stmt]
}

resource "vault_jwt_auth_backend" "user_mcp" {
  description = "JWT auth method for user-mcp OBO tokens issued by IBM Verify"
  type        = "jwt"
  path        = local.user_mcp_jwt_auth_path

  # IBM Verify's OIDC issuer (and `iss` claim value) is the tenant base URL
  # plus `/oauth2`. Vault appends `/.well-known/openid-configuration` to
  # `oidc_discovery_url` itself, so do NOT include that suffix here.
  oidc_discovery_url = local.verify_oidc_issuer
  bound_issuer       = local.verify_oidc_issuer
}

resource "vault_policy" "user_mcp_db_read" {
  name = local.user_mcp_read_policy

  policy = <<-EOT
    path "${vault_mount.database.path}/creds/${local.user_mcp_read_db_role}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "user_mcp_db_write" {
  name = local.user_mcp_write_policy

  policy = <<-EOT
    path "${vault_mount.database.path}/creds/${local.user_mcp_write_db_role}" {
      capabilities = ["read"]
    }
  EOT
}

# Glob match because IBM Verify emits `scope` as a space-separated string
# (e.g. "openid profile users.read"). bound_claims_type=glob lets us match
# tokens whose scope claim *contains* the required scope.
resource "vault_jwt_auth_backend_role" "user_mcp_read" {
  backend         = vault_jwt_auth_backend.user_mcp.path
  role_name       = local.user_mcp_read_jwt_role
  role_type       = "jwt"
  user_claim      = "preferred_username"
  bound_audiences = [local.user_mcp_audience]

  bound_claims_type = "glob"
  bound_claims = {
    scope = "*users.read*"
  }

  token_policies = [vault_policy.user_mcp_db_read.name]
  token_ttl      = 300
  token_max_ttl  = 900
  token_type     = "service"
}

resource "vault_jwt_auth_backend_role" "user_mcp_write" {
  backend         = vault_jwt_auth_backend.user_mcp.path
  role_name       = local.user_mcp_write_jwt_role
  role_type       = "jwt"
  user_claim      = "preferred_username"
  bound_audiences = [local.user_mcp_audience]

  bound_claims_type = "glob"
  bound_claims = {
    scope = "*users.write*"
  }

  token_policies = [vault_policy.user_mcp_db_write.name]
  token_ttl      = 300
  token_max_ttl  = 900
  token_type     = "service"
}
