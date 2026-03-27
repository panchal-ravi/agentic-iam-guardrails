data_dir   = "/etc/nomad.d/data"
name       = "nomad-server-0"
bind_addr  = "0.0.0.0"
datacenter = "dc1"
region     = "${nomad_region}"
log_level  = "INFO"
log_file   = "/var/log/nomad/nomad.log"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = 1
  license_path     = "/etc/nomad.d/license.hclic"
}

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

# TLS configurations
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/tls/ca.crt"
  cert_file = "/etc/nomad.d/tls/nomad.crt"
  key_file  = "/etc/nomad.d/tls/nomad.key"

  verify_server_hostname = true
  verify_https_client    = false
}

# Enable and configure ACLs
acl {
  enabled    = true
  token_ttl  = "30s"
  policy_ttl = "60s"
  role_ttl   = "60s"
}

# [optional] Specifies configuration for connecting to Consul
consul { 
  address = "127.0.0.1:8501"
  ssl = true
  token = "${consul_token}"
  ca_file = "/etc/nomad.d/tls/connect_ca.crt" //this needs to be replaced with Connect CA

  service_identity {
    aud = ["consul.io"]
    ttl = "1h"
  }

  task_identity {
    aud = ["consul.io"]
    ttl = "1h"
    env = true
    file = true
  }
}

telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
}  

ui {
  enabled = true
}

vault {
  enabled = true

  # Provide a default workload identity configuration so jobs don't need to
  # specify one.
  default_identity {
    aud  = ["vault.io"]
    env  = true
    file = true
    ttl  = "1h"

    extra_claims {
      unique_id = "$${job.region}:$${node.datacenter}:$${node.id}:$${job.namespace}:$${job.id}:$${alloc.id}"
    }
  }
}