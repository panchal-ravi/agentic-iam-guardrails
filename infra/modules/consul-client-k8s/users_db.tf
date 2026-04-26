locals {
  users_seed = jsondecode(file("${path.module}/users_seed.json"))

  users_table_ddl = <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id                 SERIAL PRIMARY KEY,
      first_name         TEXT NOT NULL,
      last_name          TEXT NOT NULL,
      ssn                TEXT NOT NULL,
      phone              TEXT NOT NULL,
      email              TEXT UNIQUE NOT NULL,
      credit_card_number TEXT NOT NULL,
      ip_address         TEXT NOT NULL
    );
  SQL

  users_seed_inserts = join("\n", [
    for u in local.users_seed :
    format(
      "INSERT INTO users (first_name, last_name, ssn, phone, email, credit_card_number, ip_address) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s') ON CONFLICT (email) DO NOTHING;",
      u.first_name, u.last_name, u.ssn, u.phone, u.email, u.credit_card_number, u.ip_address
    )
  ])

  users_schema_sql = "${local.users_table_ddl}\n${local.users_seed_inserts}\n"

  # In-cluster DNS for the postgres Service. The Vault server (on EC2)
  # reaches Postgres via the NLB; the seed Job uses kubectl exec into the
  # postgres pod itself and connects via the local Unix socket — which is
  # trust-authenticated by default in the postgres image, sidestepping any
  # password drift between the Secret and the PVC-resident pg_authid.
  postgres_in_cluster_host = "${local.postgres_service_name}.${local.postgres_namespace}.svc.cluster.local"

  users_seed_script = <<-SH
    set -eu
    NS=${local.postgres_namespace}
    POD=${local.postgres_statefulset_name}-0
    ADMIN_DB=${local.postgres_admin_db}
    USERS_DB=${local.users_db_name}
    DB_USER=${local.postgres_admin_user}

    echo "Waiting for $POD to be Ready..."
    kubectl -n "$NS" wait --for=condition=Ready "pod/$POD" --timeout=300s

    psql_exec() {
      db=$1
      shift
      kubectl -n "$NS" exec -i "$POD" -- psql -U "$DB_USER" -d "$db" -v ON_ERROR_STOP=1 "$@"
    }

    echo "Step 1/4: aligning '$DB_USER' password with the Kubernetes secret..."
    # POSTGRES_PASSWORD only takes effect on first init of the PVC. If the
    # secret was rotated after the PVC was created, the in-DB password no
    # longer matches. Realign it via Unix-socket trust auth (no password
    # required on the local socket inside the postgres container).
    ESCAPED_PW=$(printf '%s' "$DB_PASSWORD" | sed "s/'/''/g")
    psql_exec "$ADMIN_DB" -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$ESCAPED_PW'"

    echo "Step 2/4: ensuring database '$USERS_DB' exists..."
    EXISTS=$(psql_exec "$ADMIN_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$USERS_DB'")
    if [ "$EXISTS" = "1" ]; then
      echo "  database '$USERS_DB' already exists"
    else
      echo "  creating database '$USERS_DB'"
      psql_exec "$ADMIN_DB" -c "CREATE DATABASE \"$USERS_DB\""
    fi

    echo "Step 3/4: applying schema to '$USERS_DB'..."
    psql_exec "$USERS_DB" < /sql/schema.sql

    echo "Step 4/4: seeding data into '$USERS_DB'..."
    psql_exec "$USERS_DB" < /sql/seed.sql

    echo "Done."
  SH

  # Suffix the (immutable) Job and ConfigMap names with a hash that covers
  # the SQL, the wrapper script, AND the admin password. Any change forces
  # a fresh Job, ensuring password realignment runs after rotations.
  users_seed_sha = substr(sha256(join("|", [
    local.users_schema_sql,
    local.users_seed_script,
    var.postgres_admin_password,
  ])), 0, 10)
}

resource "kubernetes_config_map_v1" "users_schema_seed" {
  metadata {
    name      = "users-schema-seed-${local.users_seed_sha}"
    namespace = local.postgres_namespace
  }

  data = {
    "schema.sql" = local.users_table_ddl
    "seed.sql"   = local.users_seed_inserts
  }
}

resource "kubernetes_service_account_v1" "users_schema_seed" {
  metadata {
    name      = "users-schema-seed"
    namespace = local.postgres_namespace
  }
}

resource "kubernetes_role_v1" "users_schema_seed" {
  metadata {
    name      = "users-schema-seed"
    namespace = local.postgres_namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }
}

resource "kubernetes_role_binding_v1" "users_schema_seed" {
  metadata {
    name      = "users-schema-seed"
    namespace = local.postgres_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.users_schema_seed.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.users_schema_seed.metadata[0].name
    namespace = local.postgres_namespace
  }
}

resource "kubernetes_job_v1" "users_schema_seed" {
  depends_on = [
    kubernetes_stateful_set_v1.postgres,
    kubernetes_role_binding_v1.users_schema_seed,
  ]

  metadata {
    name      = "users-schema-seed-${local.users_seed_sha}"
    namespace = local.postgres_namespace
  }

  spec {
    backoff_limit = 5

    template {
      metadata {
        labels = {
          app = "users-schema-seed"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = kubernetes_service_account_v1.users_schema_seed.metadata[0].name

        container {
          name  = "seed"
          image = "alpine/k8s:1.30.0"

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres_credentials.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          command = ["/bin/sh", "-c"]
          args    = [local.users_seed_script]

          volume_mount {
            name       = "sql"
            mount_path = "/sql"
            read_only  = true
          }
        }

        volume {
          name = "sql"

          config_map {
            name = kubernetes_config_map_v1.users_schema_seed.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "10m"
    update = "10m"
  }
}
