#!/bin/bash

echo ${nomad_license} > /etc/nomad.d/license.hclic
cat > /etc/nomad.d/tls/connect_ca.crt <<-EOF
${connect_ca_crt}
EOF

cat > /etc/nomad.d/tls/ca.crt <<-EOF
${nomad_ca_crt}
EOF

%{ if agent_type == "server" }

#Write Nomad server config
cat > /etc/nomad.d/nomad.hcl <<-'EOF'
${nomad_server_config}
EOF

#Write nomad tls certs
cat > /etc/nomad.d/tls/nomad.crt <<-EOF
${nomad_server_crt}
EOF

cat > /etc/nomad.d/tls/nomad.key <<-EOF
${nomad_server_key}
EOF

%{ else }

#Write Nomad client config
cat > /etc/nomad.d/nomad.hcl <<-'EOF'
${nomad_client_config}
EOF

#Write nomad tls certs
cat > /etc/nomad.d/tls/nomad.crt <<-EOF
${nomad_client_crt}
EOF

cat > /etc/nomad.d/tls/nomad.key <<-EOF
${nomad_client_key}
EOF

%{ endif }

sudo usermod -G docker -a nomad
sudo usermod -G docker -a ubuntu

sudo chown -R nomad:nomad /etc/nomad.d
sudo systemctl start nomad