# -----------------------------------------------------
# EKS Cluster + Managed Node Group
# Public endpoint enabled for workshop simplicity.
# Attendees connect directly via kubeconfig.
# -----------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public endpoint so attendees can reach the API server
  # from conference wifi without a VPN or bastion.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # EKS managed addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        # Enable NetworkPolicy support via VPC CNI
        enableNetworkPolicy = "true"
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    workshop = {
      name           = "${var.cluster_name}-workers"
      instance_types = [var.node_instance_type]

      min_size     = var.node_count
      max_size     = var.node_count
      desired_size = var.node_count

      # Workshop clusters are ephemeral. On-demand is fine.
      capacity_type = "ON_DEMAND"

      labels = {
        role = "workshop"
      }
    }
  }

  # Allow the provisioner IAM role and the attendee to access the cluster
  enable_cluster_creator_admin_permissions = true

  # Access entries for attendee kubectl access.
  # The provisioning script adds the attendee IAM role post-creation.
  access_entries = {}
}
