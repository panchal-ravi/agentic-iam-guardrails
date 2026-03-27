#!/bin/bash

# Install Vault from HashiCorp apt repository
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vault

sudo mkdir -p /etc/vault.d/data
sudo mkdir -p /opt/vault/data

cat > /etc/vault.d/vault.hcl <<-'EOF'
${vault_config}
EOF

cat > /etc/vault.d/vault.crt <<-EOF
${vault_crt}
EOF

cat > /etc/vault.d/vault.key <<-EOF
${vault_key}
EOF

cat > /etc/systemd/system/vault.service <<-'SVCEOF'
${vault_service}
SVCEOF

sudo chown -R vault:vault /opt/vault/data
sudo chown -R vault:vault /etc/vault.d
sudo chmod 664 /etc/systemd/system/vault.service
sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault
