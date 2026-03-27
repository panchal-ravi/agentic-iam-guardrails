output "server_ip" {
  value = aws_instance.server.private_ip
}

output "service_ip" {
  value = aws_instance.server.private_ip
}

output "consul_token" {
  value = random_uuid.management_token.id
}

output "consul_ca_crt" {
  value = tls_self_signed_cert.consul_ca_cert.cert_pem
}

output "connect_ca_crt" {
  value = replace(trim(data.jq_query.root_certs.result, "\""), "\\n", "\n")
}

output "vault_ca_crt" {
  value = tls_self_signed_cert.vault_ca_cert.cert_pem
}

output "nomad_ca_crt" {
  value = tls_self_signed_cert.nomad_ca_cert.cert_pem
}

output "nomad_ca_key_pem" {
  value     = tls_private_key.nomad_ca_private_key.private_key_pem
  sensitive = true
}
