#!/bin/bash

echo ${consul_license} > /etc/consul.d/license.hclic
echo ${nomad_license} > /etc/nomad.d/license.hclic

%{ if agent_type == "server" }
#Write Nomad server config
cat > /etc/nomad.d/nomad.hcl <<-EOF
data_dir   = "/etc/nomad.d/data"
name       = "nomad-server-0"
bind_addr  = "0.0.0.0"
datacenter = "dc1"
region     = "sg"
log_level  = "INFO"
log_file   = "/var/log/nomad/nomad.log"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = 1
  license_path     = "/etc/nomad.d/license.hclic"
}

telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
}  

ui {
  enabled = true
}
EOF

#Write Consul server config
cat > /etc/consul.d/consul.hcl <<-EOF
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
ports {
    http = 8500
    https = -1
    grpc = 8502
    #grpc_tls = -1
    dns = 8600
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
EOF

%{ else }
#Write Nomad client config
cat > /etc/nomad.d/nomad.hcl <<-EOF
data_dir   = "/etc/nomad.d/data"
name       = "nomad-client-0"
bind_addr  = "0.0.0.0"
datacenter = "dc1"
region     = "sg"
log_level  = "INFO"
log_file   = "/var/log/nomad/nomad.log"

# Enable the client
client {
  enabled = true
  server_join {
    retry_join = ["provider=aws tag_key=\"agent_type\" tag_value=\"server\""]
  }
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
EOF

#Write Consul client config
cat > /etc/consul.d/consul.hcl <<-EOF
data_dir   = "/etc/consul.d/data"
node_name  = "consul-client-0"
bind_addr  = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "{{ GetInterfaceIP \"ens5\" }}"
datacenter = "dc1"
log_level  = "INFO"
log_file   = "/var/log/consul/consul.log"
license_path = "/etc/consul.d/license.hclic"

server = false
retry_join = ["provider=aws tag_key=\"agent_type\" tag_value=\"server\""]

ports {
    http = 8500
    https = -1
    grpc = 8502
    #grpc_tls = -1
    dns = 8600
}
EOF

sudo usermod -G docker -a nomad
sudo usermod -G docker -a ubuntu
%{ endif }

sudo chown -R nomad:nomad /etc/nomad.d
sudo chown -R consul:consul /etc/consul.d