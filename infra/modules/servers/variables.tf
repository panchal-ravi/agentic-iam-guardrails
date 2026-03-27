variable "deployment_id" {}
variable "owner" {}
variable "instance_type" {}
variable "private_subnets" {}
variable "aws_keypair_name" {}
variable "bastion_sg_id" {}
variable "nomad_sg_id" {}
variable "consul_sg_id" {}
variable "vault_sg_id" {}
variable "iam_instance_profile" {}
variable "vpc_id" {}
variable "elb" {}
variable "bastion_ip" {}
variable "ssh_key" {
  sensitive = true
}
