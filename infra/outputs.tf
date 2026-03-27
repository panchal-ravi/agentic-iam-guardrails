output "consul_http_addr" {
  value = "https://${module.common.elb.http_addr}:8501"
}

output "nomad_http_addr" {
  value = "https://${module.common.elb.http_addr}:4646"
}

output "vault_http_addr" {
  value = "https://${module.common.elb.http_addr}:8200"
}

output "server_ip" {
  value = module.servers.server_ip
}

output "consul_token" {
  value = module.servers.consul_token
}

output "nomad_client_ips" {
  value = module.clients.nomad_client_ips
}

output "bastion_ip" {
  value = module.common.bastion_ip
}


# output "connect_ca_crt" {
#   value = module.servers.connect_ca_crt
# }

# output "ssh_key" {
#   value     = module.common.ssh_key
#   sensitive = true
# }

