output "nomad_client_ips" {
  value = aws_instance.nomad_client[*].private_ip
}
