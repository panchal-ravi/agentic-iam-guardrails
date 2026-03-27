#!/bin/bash

mkdir -p /etc/consul.d/tls
mkdir -p /etc/nomad.d/tls

#Download istioctl and fake-service
export WORKING_DIR=/home/ubuntu
cd $WORKING_DIR 
wget https://github.com/nicholasjackson/fake-service/releases/download/v0.26.2/fake_service_linux_amd64.zip && unzip fake_service_linux_amd64.zip && chmod +x fake-service
curl -sL https://istio.io/downloadIstioctl | sh -

mv $HOME/.istioctl/bin/istioctl /usr/local/bin

cat > /etc/systemd/system/nomad.service <<-EOF
${nomad_service}
EOF

cat > /etc/systemd/system/consul.service <<-EOF
${consul_service}
EOF

systemctl daemon-reload