storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "false"
  tls_cert_file = "/etc/vault.d/vault.crt"
  tls_key_file = "/etc/vault.d/vault.key"
}

disable_mlock = true
log_level     = "Trace"
log_format    = "standard"
api_addr      = "https://0.0.0.0:8200"
cluster_addr  = "https://127.0.0.1:8201"
ui            = true
