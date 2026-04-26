output "postgres_internal_nlb_host" {
  description = "Internal NLB hostname of the postgres service (used by the Vault DB engine on the EC2 servers)"
  value       = kubernetes_service_v1.postgres_internal_lb.status[0].load_balancer[0].ingress[0].hostname
}

output "postgres_in_cluster_host" {
  description = "Cluster-internal DNS name of the postgres service"
  value       = local.postgres_in_cluster_host
}

output "postgres_users_db" {
  description = "Postgres database holding the users table"
  value       = local.users_db_name
}

output "user_mcp_jwt_auth_path" {
  description = "Vault auth path for the user-mcp JWT backend (auth/<path>)"
  value       = vault_jwt_auth_backend.user_mcp.path
}

output "user_mcp_db_read_role" {
  description = "Vault DB role issuing read-only Postgres credentials for user-mcp"
  value       = vault_database_secret_backend_role.user_mcp_read.name
}

output "user_mcp_db_write_role" {
  description = "Vault DB role issuing read+write Postgres credentials for user-mcp"
  value       = vault_database_secret_backend_role.user_mcp_write.name
}
