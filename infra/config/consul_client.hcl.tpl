data_dir   = "/etc/consul.d/data"
node_name  = "${node_name}"
bind_addr  = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "{{ GetInterfaceIP \"ens5\" }}"
datacenter = "dc1"
log_level  = "INFO"
log_file   = "/var/log/consul/consul.log"
license_path = "/etc/consul.d/license.hclic"

server = false
retry_join = ["provider=aws tag_key=\"consul_agent_type\" tag_value=\"consul-server\""]

tls {
    defaults {
      ca_file = "/etc/consul.d/tls/ca.crt"
      verify_outgoing = true
    }
    internal_rpc {
      // verify_incoming = true // Not applicable for client agents
      verify_server_hostname = true
    }
    https {
      // verify_incoming = true // This would require client TLS private/public key to communicate with Server HTTPs
    }
    grpc {
      // use_auto_cert = true // Comment this if Consul > 1.13
    }
}

auto_encrypt {
  tls = true
  ip_san = [ "{{ GetInterfaceIP \"ens5\" }}"]
}

ports {
  http = -1
  https = 8501
  grpc = 8502
  grpc_tls = 8503 
}

connect {
  enabled = true
}

recursors = ["8.8.8.8", "1.1.1.1"]