// Nomad Client Certificate
resource "tls_private_key" "nomad_client_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "nomad_client_csr" {

  private_key_pem = tls_private_key.nomad_client_private_key.private_key_pem

  dns_names    = ["nomad.demo.com", "client.${local.nomad_region}.nomad", "localhost"]
  ip_addresses = ["127.0.0.1"]

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "client.${local.nomad_region}.nomad"
    organization        = "Demo Organization"
    organizational_unit = "Development"
  }
}

# Sign Client Certificate by Private CA
resource "tls_locally_signed_cert" "nomad_client_signed_cert" {
  cert_request_pem   = tls_cert_request.nomad_client_csr.cert_request_pem
  ca_private_key_pem = var.nomad_ca_key_pem
  ca_cert_pem        = var.nomad_ca_cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

// Nomad CLI Certificate
resource "tls_private_key" "nomad_cli_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "nomad_cli_csr" {

  private_key_pem = tls_private_key.nomad_cli_private_key.private_key_pem

  dns_names    = ["cli.${local.nomad_region}.nomad", "localhost"]
  ip_addresses = ["127.0.0.1"]

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "cli.${local.nomad_region}.nomad"
    organization        = "Demo Organization"
    organizational_unit = "Development"
  }
}

# Sign CLI Certificate by Private CA
resource "tls_locally_signed_cert" "nomad_cli_signed_cert" {
  cert_request_pem   = tls_cert_request.nomad_cli_csr.cert_request_pem
  ca_private_key_pem = var.nomad_ca_key_pem
  ca_cert_pem        = var.nomad_ca_cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}
