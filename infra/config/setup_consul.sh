#!/bin/bash
echo ${consul_license} > /etc/consul.d/license.hclic
mkdir -p /etc/consul.d/tls
cat > /etc/consul.d/tls/ca.crt <<-EOF
${consul_ca_crt}
EOF

%{ if agent_type == "server" }

#Write Consul server config
cat > /etc/consul.d/consul.hcl <<-EOF
${consul_server_config}
EOF

#Write consul tls certs
cat > /etc/consul.d/tls/consul.crt <<-EOF
${consul_server_crt}
EOF

cat > /etc/consul.d/tls/consul.key <<-EOF
${consul_server_key}
EOF

cat > /etc/consul.d/acl.hcl <<-EOF
${consul_server_acl}
EOF

%{ else }

cat > /etc/consul.d/consul.hcl <<-EOF
${consul_client_config}
EOF

cat > /etc/consul.d/acl.hcl <<-EOF
${consul_client_acl}
EOF

%{ endif }

sudo chown -R consul:consul /etc/consul.d

sleep 5
sudo systemctl start consul
sleep 5
# sudo systemctl start nomad