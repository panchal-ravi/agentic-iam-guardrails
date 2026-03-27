locals {
  nomad_region            = "sg"
  consul_datacenter       = "dc1"
  consul_auth_method_name = "nomad-workloads"
  tasks_role_prefix       = "nomad-tasks"
}

data "aws_ami" "an_image" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["${var.owner}-consul-nomad-enterprise*"]
  }
}

resource "consul_acl_policy" "nomad_client" {
  name  = "nomad-client"
  rules = file("${path.root}/config/consul_acl_policy_for_nomad_client.hcl")
}

resource "consul_acl_token" "nomad_client" {
  count       = var.nomad_client_count
  description = "Token for nomad client nomad-client-${count.index}"
  policies    = [consul_acl_policy.nomad_client.name]
}

resource "consul_acl_token" "consul_client" {
  count       = var.nomad_client_count
  description = "Token for Consul client agent consul-client-${count.index}"
  node_identities {
    node_name  = "nomad-client-${count.index}"
    datacenter = local.consul_datacenter
  }
}

data "consul_acl_token_secret_id" "nomad_client" {
  count       = var.nomad_client_count
  accessor_id = element(consul_acl_token.nomad_client, count.index).id
}

data "consul_acl_token_secret_id" "consul_client" {
  count       = var.nomad_client_count
  accessor_id = element(consul_acl_token.consul_client, count.index).id
}

data "cloudinit_config" "init_client" {
  count         = var.nomad_client_count
  gzip          = false
  base64_encode = false

  part {
    filename     = "setup_common.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_common.sh", {
      consul_service = file("${path.root}/config/consul.service")
      nomad_service = templatefile("${path.root}/config/nomad.service", {
        agent_type = "client"
      })
    })
  }

  part {
    filename     = "setup_nomad.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_nomad.sh", {
      nomad_license    = file("${path.root}/config/nomad_license.hclic")
      nomad_client_crt = tls_locally_signed_cert.nomad_client_signed_cert.cert_pem
      nomad_client_key = tls_private_key.nomad_client_private_key.private_key_pem
      nomad_ca_crt     = var.nomad_ca_cert_pem
      connect_ca_crt   = var.connect_ca_crt
      vault_ca_crt     = var.vault_ca_crt
      nomad_client_config = templatefile("${path.root}/config/nomad_client.hcl.tpl", {
        nomad_region            = local.nomad_region
        index                   = count.index
        consul_token            = data.consul_acl_token_secret_id.nomad_client[count.index].secret_id
        consul_auth_method_name = local.consul_auth_method_name
        vault_addr              = "https://${var.elb.http_addr}:8200"
      })
      agent_type          = "client"
      nomad_server_config = ""
      nomad_server_crt    = ""
      nomad_server_key    = ""
    })
  }


  part {
    filename     = "setup_consul.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/config/setup_consul.sh", {
      consul_license = file("${path.root}/config/consul_license.hclic")
      agent_type     = "client"
      consul_ca_crt  = var.consul_ca_crt
      consul_client_acl = templatefile("${path.root}/config/consul_client_acl.hcl.tpl", {
        agent_token = data.consul_acl_token_secret_id.consul_client[count.index].secret_id
      })
      consul_client_config = templatefile("${path.root}/config/consul_client.hcl.tpl", {
        node_name = "nomad-client-${count.index}"
      })
      consul_server_acl    = ""
      consul_server_config = ""
      consul_server_crt    = ""
      consul_server_key    = ""
    })
  }
}

resource "aws_instance" "nomad_client" {
  count                = var.nomad_client_count
  ami                  = data.aws_ami.an_image.id
  instance_type        = var.instance_type
  key_name             = var.aws_keypair_name
  subnet_id            = element(var.private_subnets, 1)
  security_groups      = [var.bastion_sg_id, var.nomad_sg_id, var.consul_sg_id]
  iam_instance_profile = var.iam_instance_profile
  user_data            = data.cloudinit_config.init_client[count.index].rendered

  tags = {
    Name = "${var.deployment_id}-nomad-client-${count.index}"
  }

  lifecycle {
    ignore_changes = all
  }

}
