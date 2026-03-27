data_dir   = "/etc/consul.d/data"
node_name  = "consul-server-0"
bind_addr  = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "{{ GetInterfaceIP \"ens5\" }}"
datacenter = "dc1"
log_level  = "INFO"
log_file   = "/var/log/consul/consul.log"
license_path = "/etc/consul.d/license.hclic"

server = true
bootstrap_expect = 1

tls {
  defaults {
    ca_file = "/etc/consul.d/tls/ca.crt"
    cert_file = "/etc/consul.d/tls/consul.crt"
    key_file = "/etc/consul.d/tls/consul.key"
    verify_outgoing = true
  }
  internal_rpc {
    verify_incoming = true
    verify_server_hostname = true
  }
  https {
    // verify_incoming = true // This would require client TLS private/public key to communicate with Server HTTPs
  }
}

ports {
    http = -1
    https = 8501
    grpc = 8502
    grpc_tls = 8503
    # dns = 8600
}

auto_encrypt {
  allow_tls = true
}

telemetry {
    prometheus_retention_time = "60s"
    disable_hostname = true
}

ui_config {
    enabled = true
    metrics_provider = "prometheus"
}

connect {
    enabled = true
}