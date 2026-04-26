locals {
  postgres_namespace        = "default"
  postgres_app_label        = "postgres"
  postgres_service_name     = "postgres-internal-lb"
  postgres_statefulset_name = "postgres"
  postgres_secret_name      = "postgres-credentials"
  postgres_admin_user       = "vault_user"
  postgres_admin_db         = "postgres"
  users_db_name             = "users"
}

resource "kubernetes_secret_v1" "postgres_credentials" {
  metadata {
    name      = local.postgres_secret_name
    namespace = local.postgres_namespace
  }

  data = {
    POSTGRES_USER     = local.postgres_admin_user
    POSTGRES_PASSWORD = var.postgres_admin_password
    POSTGRES_DB       = local.postgres_admin_db
  }

  type = "Opaque"
}

resource "kubernetes_stateful_set_v1" "postgres" {
  metadata {
    name      = local.postgres_statefulset_name
    namespace = local.postgres_namespace
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = local.postgres_app_label
      }
    }

    template {
      metadata {
        labels = {
          app = local.postgres_app_label
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16"

          port {
            container_port = 5432
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres_credentials.metadata[0].name
            }
          }

          volume_mount {
            name       = "postgresdb-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgresdb-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.postgres_storage_class

        resources {
          requests = {
            storage = var.postgres_storage_size
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres_internal_lb" {
  metadata {
    name      = local.postgres_service_name
    namespace = local.postgres_namespace

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = local.postgres_app_label
    }

    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 5432
    }
  }

  wait_for_load_balancer = true
}
