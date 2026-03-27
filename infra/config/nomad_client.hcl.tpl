data_dir   = "/etc/nomad.d/data"
name       = "nomad-client-${index}"
bind_addr  = "0.0.0.0"
datacenter = "dc1"
region     = "sg"
log_level  = "INFO"
log_file   = "/var/log/nomad/nomad.log"

ports {
  http = 4646
  rpc  = 4647
  // serf = 4648 //Not required by client
}

tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/tls/ca.crt"
  cert_file = "/etc/nomad.d/tls/nomad.crt"
  key_file  = "/etc/nomad.d/tls/nomad.key"

  verify_server_hostname = true
  verify_https_client    = false
}

# Enable the client
client {
  enabled = true
  # Comment below lines if Consul is also running
  # server_join {
  #   retry_join = ["provider=aws tag_key=\"agent_type\" tag_value=\"server\""]
  # }
}

# Enable and configure ACLs
acl {
  enabled    = true
  token_ttl  = "30s"
  policy_ttl = "60s"
  role_ttl   = "60s"
}

consul { 
  address = "127.0.0.1:8501"
  grpc_address = "127.0.0.1:8503"
  ssl = true
  token = "${consul_token}"
  ca_file = "/etc/nomad.d/tls/connect_ca.crt" // This needs to be replaced with Connect CA
  grpc_ca_file = "/etc/nomad.d/tls/connect_ca.crt"

  service_auth_method = "${consul_auth_method_name}" // Name of the Consul authentication method used to login with Nomad JWT for services
  task_auth_method = "${consul_auth_method_name}" // Name of the Consul authentication method used to login with Nomad JWT for tasks
}

telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

plugin "docker" {
  config {
    allow_privileged = true
  }
}

vault {
  enabled   = true
  address   = "${vault_addr}"
  jwt_auth_backend_path = "jwt"
  # ca_path   = "/etc/nomad.d/tls/vault_ca.crt"
  # cert_file = "/var/certs/vault.crt"
  # key_file  = "/var/certs/vault.key"
  tls_skip_verify = true
}