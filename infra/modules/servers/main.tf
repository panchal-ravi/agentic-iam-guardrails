locals {
  nomad_region      = "sg"
  consul_datacenter = "dc1"
}

resource "random_uuid" "management_token" {}

data "aws_ami" "an_image" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["${var.owner}-consul-nomad-enterprise*"]
  }
}

data "cloudinit_config" "init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "setup_common.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_common.sh", {
      consul_service = file("${path.root}/config/consul.service")
      nomad_service = templatefile("${path.root}/config/nomad.service", {
        agent_type = "server"
      })
    })
  }

  part {
    filename     = "setup_vault.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_vault.sh", {
      vault_config  = file("${path.root}/config/vault_config.hcl")
      vault_service = file("${path.root}/config/vault.service")
      vault_crt     = join("\n", [tls_locally_signed_cert.vault_server_signed_cert.cert_pem, tls_self_signed_cert.vault_ca_cert.cert_pem])
      vault_key     = tls_private_key.vault_server_private_key.private_key_pem
    })
  }

  part {
    filename     = "setup_consul.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_consul.sh", {
      agent_type           = "server"
      consul_license       = file("${path.root}/config/consul_license.hclic")
      consul_server_config = file("${path.root}/config/consul_server.hcl")
      consul_client_config = ""
      consul_client_acl    = ""
      consul_ca_crt        = tls_self_signed_cert.consul_ca_cert.cert_pem
      consul_server_crt    = tls_locally_signed_cert.consul_server_signed_cert.cert_pem
      consul_server_key    = tls_private_key.consul_server_private_key.private_key_pem
      consul_server_acl = templatefile("${path.root}/config/consul_server_acl.hcl.tpl", {
        management_token = random_uuid.management_token.id
      })
    })
  }

  part {
    filename     = "setup_nomad.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_nomad.sh", {
      nomad_license    = file("${path.root}/config/nomad_license.hclic")
      nomad_server_crt = tls_locally_signed_cert.nomad_server_signed_cert.cert_pem
      nomad_server_key = tls_private_key.nomad_server_private_key.private_key_pem
      nomad_ca_crt     = tls_self_signed_cert.nomad_ca_cert.cert_pem
      # Use the Consul CA as the connect CA; valid at bootstrap since Connect CA starts as the Consul CA
      connect_ca_crt = tls_self_signed_cert.consul_ca_cert.cert_pem
      vault_ca_crt   = tls_self_signed_cert.vault_ca_cert.cert_pem
      nomad_server_config = templatefile("${path.root}/config/nomad_server.hcl.tpl", {
        nomad_region = local.nomad_region
        consul_token = random_uuid.management_token.id
      })
      agent_type          = "server"
      nomad_client_config = ""
      nomad_client_crt    = ""
      nomad_client_key    = ""
    })
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.an_image.id
  instance_type          = var.instance_type
  key_name               = var.aws_keypair_name
  vpc_security_group_ids = [var.bastion_sg_id, var.nomad_sg_id, var.consul_sg_id, var.vault_sg_id]
  subnet_id              = element(var.private_subnets, 0)
  iam_instance_profile   = var.iam_instance_profile
  user_data              = data.cloudinit_config.init.rendered

  tags = {
    Name              = "${var.deployment_id}-server"
    owner             = var.owner
    consul_agent_type = "consul-server"
    nomad_agent_type  = "nomad-server"
  }

  lifecycle {
    ignore_changes = all
  }

  provisioner "remote-exec" {
    inline = [
      # Set variables for the session
      "export VAULT_ADDR='https://127.0.0.1:8200'",
      "export VAULT_SKIP_VERIFY=true",
      "export VAULT_TLS_SERVER_NAME='demo.server.vault'",
      "until curl -sk --connect-timeout 2 https://127.0.0.1:8200/v1/sys/health >/dev/null; do sleep 2; done",

      # Initialize and capture output
      "vault operator init -n 1 -t 1 -format=json > /home/ubuntu/init.json",

      # Use single $ if you want the shell to execute it; 
      # Terraform treats $() as a literal string anyway.
      "unseal_key=$(jq -r '.unseal_keys_b64[0]' /home/ubuntu/init.json)",

      # Pass the variable explicitly to sudo
      "vault operator unseal \"$unseal_key\"",

      "jq -r .root_token /home/ubuntu/init.json > /home/ubuntu/vault_token",
      "echo '.................................Done vault setup.........................................'"
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -i ${path.root}/generated/ssh_key ubuntu@${var.bastion_ip} "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /home/ubuntu/ssh_key ubuntu@${self.private_ip}:/home/ubuntu/vault_token /home/ubuntu/vault_token"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${path.root}/generated/ssh_key ubuntu@${var.bastion_ip}:/home/ubuntu/vault_token ./generated/
      EOT
  }

  connection {
    bastion_host        = var.bastion_ip
    bastion_user        = "ubuntu"
    agent               = false
    bastion_private_key = var.ssh_key

    host        = self.private_ip
    user        = "ubuntu"
    private_key = var.ssh_key
  }

  depends_on = [
    aws_lb_target_group.vault_lb_tg,
    aws_lb_target_group.consul_lb_tg,
    aws_lb_target_group.nomad_lb_tg,
  ]
}

resource "time_sleep" "wait_for_services" {
  create_duration = "30s"
  depends_on      = [aws_instance.server]
}

data "http" "connect_ca" {
  url      = "https://${var.elb.http_addr}:8501/v1/connect/ca/roots"
  insecure = true
  request_headers = {
    Accept = "application/json"
  }

  depends_on = [time_sleep.wait_for_services]
}

data "jq_query" "root_certs" {
  data  = data.http.connect_ca.response_body
  query = ".Roots[].RootCert"
}

resource "null_resource" "nomad_acl_bootstrap" {
  provisioner "local-exec" {
    command = <<-EOF
        curl -s -k -X POST https://${var.elb.http_addr}:4646/v1/acl/bootstrap | jq -r .SecretID > ${path.root}/generated/nomad_management_token
      EOF
  }
  depends_on = [time_sleep.wait_for_services]
}

resource "null_resource" "delete_vault_token" {
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOD
      rm ${path.root}/generated/vault_token || true
      EOD
  }
}
