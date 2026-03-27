# =====================
# Vault ELB (port 8200)
# =====================

resource "aws_acm_certificate" "vault_cert" {
  private_key       = tls_private_key.vault_server_private_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.vault_server_signed_cert.cert_pem
  certificate_chain = tls_self_signed_cert.vault_ca_cert.cert_pem
}

resource "aws_lb_listener" "vault_lb_listener" {
  load_balancer_arn = var.elb.arn
  port              = "8200"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.vault_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault_lb_tg.arn
  }
}

resource "aws_lb_target_group" "vault_lb_tg" {
  name        = "${var.deployment_id}-vault-lb-tg"
  port        = 8200
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/v1/sys/health"
    port                = 8200
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 2
  }
}

resource "aws_lb_target_group_attachment" "vault_lb_tg_attachment" {
  port             = 8200
  target_group_arn = aws_lb_target_group.vault_lb_tg.arn
  target_id        = aws_instance.server.id
}

# =====================
# Consul ELB (port 8501)
# =====================

resource "aws_acm_certificate" "consul_cert" {
  private_key       = tls_private_key.consul_server_private_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.consul_server_signed_cert.cert_pem
  certificate_chain = tls_self_signed_cert.consul_ca_cert.cert_pem
}

resource "aws_lb_listener" "consul_lb_listener" {
  load_balancer_arn = var.elb.arn
  port              = "8501"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.consul_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul_lb_tg.arn
  }
}

resource "aws_lb_target_group" "consul_lb_tg" {
  name        = "${var.deployment_id}-c-lb-tg-sg"
  port        = 8501
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/v1/status/leader"
    port                = 8501
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 2
  }
}

resource "aws_lb_target_group_attachment" "consul_lb_tg_attachment" {
  target_group_arn = aws_lb_target_group.consul_lb_tg.arn
  target_id        = aws_instance.server.id
  port             = 8501
}

# =====================
# Nomad ELB (port 4646)
# =====================

resource "aws_acm_certificate" "nomad_cert" {
  private_key       = tls_private_key.nomad_server_private_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.nomad_server_signed_cert.cert_pem
  certificate_chain = tls_self_signed_cert.nomad_ca_cert.cert_pem
}

resource "aws_lb_listener" "nomad_lb_listener" {
  load_balancer_arn = var.elb.arn
  port              = "4646"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.nomad_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad_lb_tg.arn
  }
}

resource "aws_lb_target_group" "nomad_lb_tg" {
  name        = "${var.deployment_id}-nomad-lb-tg-sg"
  port        = 4646
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/v1/agent/health"
    port                = 4646
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 2
  }
}

resource "aws_lb_target_group_attachment" "nomad_lb_tg_attachment" {
  target_group_arn = aws_lb_target_group.nomad_lb_tg.arn
  target_id        = aws_instance.server.id
  port             = 4646
}
