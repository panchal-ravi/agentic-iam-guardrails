# =====================
# Vault TLS (RSA)
# =====================

resource "tls_private_key" "vault_ca_private_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "vault_ca_cert" {
  private_key_pem = tls_private_key.vault_ca_private_key.private_key_pem

  is_ca_certificate = true

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "Demo Root CA"
    organization        = "Demo Organization"
    organizational_unit = "Demo Organization Vault Root Certification Authority"
  }

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "vault_server_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "vault_server_csr" {
  private_key_pem = tls_private_key.vault_server_private_key.private_key_pem

  dns_names    = ["demo.server.vault", "localhost"]
  ip_addresses = ["127.0.0.1"]

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "demo.server.vault"
    organization        = "Demo Organization"
    organizational_unit = "Development"
  }
}

resource "tls_locally_signed_cert" "vault_server_signed_cert" {
  cert_request_pem   = tls_cert_request.vault_server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.vault_ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vault_ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# =====================
# Consul TLS (ECDSA)
# =====================

resource "tls_private_key" "consul_ca_private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "consul_ca_cert" {
  private_key_pem = tls_private_key.consul_ca_private_key.private_key_pem

  is_ca_certificate = true

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "Demo Root CA"
    organization        = "Demo Organization"
    organizational_unit = "Demo Organization Root Certification Authority"
  }

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "consul_server_private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "consul_server_csr" {
  private_key_pem = tls_private_key.consul_server_private_key.private_key_pem

  dns_names    = ["server.dc1.consul", "localhost", "${var.elb.http_addr}"]
  ip_addresses = ["127.0.0.1"]

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "server.dc1.consul"
    organization        = "Demo Organization"
    organizational_unit = "Development"
  }
}

resource "tls_locally_signed_cert" "consul_server_signed_cert" {
  cert_request_pem   = tls_cert_request.consul_server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.consul_ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul_ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# =====================
# Nomad Server TLS (RSA)
# =====================

resource "tls_private_key" "nomad_ca_private_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "nomad_ca_cert" {
  private_key_pem = tls_private_key.nomad_ca_private_key.private_key_pem

  is_ca_certificate = true

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "Demo Root CA"
    organization        = "Demo Organization"
    organizational_unit = "Demo Organization Nomad Root Certification Authority"
  }

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "nomad_server_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "nomad_server_csr" {
  private_key_pem = tls_private_key.nomad_server_private_key.private_key_pem

  dns_names    = ["server.${local.nomad_region}.nomad", "localhost", "${var.elb.http_addr}"]
  ip_addresses = ["127.0.0.1"]

  subject {
    country             = "SG"
    province            = "Singapore"
    locality            = "Singapore"
    common_name         = "server.${local.nomad_region}.nomad"
    organization        = "Demo Organization"
    organizational_unit = "Development"
  }
}

resource "tls_locally_signed_cert" "nomad_server_signed_cert" {
  cert_request_pem   = tls_cert_request.nomad_server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.nomad_ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}
