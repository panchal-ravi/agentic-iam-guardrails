output "bastion_sg_id" {
  value = module.bastion_sg.security_group_id
}
output "consul_sg_id" {
  value = module.consul_sg.security_group_id
}
output "nomad_sg_id" {
  value = module.nomad_sg.security_group_id
}
output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "iam_instance_profile" {
  value = aws_iam_instance_profile.instance_profile.name
}
output "aws_keypair_name" {
  value = aws_key_pair.this.key_name
}
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vault_sg_id" {
  value = module.vault_sg.security_group_id
}

output "ssh_key" {
  value = tls_private_key.ssh.private_key_openssh
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "elb" {
  value = {
    arn       = aws_lb.http_lb.arn,
    http_addr = aws_lb.http_lb.dns_name,
  }
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_oidc_provider" {
  description = "OIDC provider URL for the EKS cluster"
  value       = module.eks.oidc_provider
}
