
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.deployment_id
  kubernetes_version = var.kubernetes_version

  endpoint_public_access                   = true
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    example = {
      desired_size = 2
      max_size     = 3
      min_size     = 1
      # instance_types = ["t3.medium"]
      instance_types = ["m5.large"]
    }
  }

  node_security_group_additional_rules = {
    ingress_control_plane_all = {
      description                   = "Allow all traffic from control plane"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true # Automatically uses the cluster's primary SG
    }
  }

  security_group_additional_rules = {
    ingress_consul_servers_https = {
      description              = "Allow Consul servers to reach the EKS API endpoint for TokenReview"
      from_port                = 443
      protocol                 = "tcp"
      source_security_group_id = module.consul_sg.security_group_id
      to_port                  = 443
      type                     = "ingress"
    }
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKS_EBS_CSI_DriverRole"
    }
  }

  tags = {
    owner     = var.owner
    terraform = "true"
  }
}


resource "null_resource" "kubeconfig" {

  provisioner "local-exec" {
    command = <<-EOT
      aws eks --region ${var.region} update-kubeconfig --kubeconfig ${path.root}/generated/${var.deployment_id}-kubeconfig --name ${module.eks.cluster_name};
      EOT
  }

  depends_on = [
    module.eks
  ]
}


data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ebs-csi-role" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${split("/", module.eks.oidc_provider)[2]}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com",
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ebs_csi_role_attach" {
  role       = aws_iam_role.ebs-csi-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
