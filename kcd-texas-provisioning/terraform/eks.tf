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
      # Node group name must NOT include the cluster name -- the EKS module
      # appends "-eks-node-group-<random>" to derive the IAM role name_prefix,
      # which has a 38-char limit.  cluster_name="kcd-tx-attendee-NN" (20
      # chars) + "-workers" + "-eks-node-group-" already busts that limit
      # before the random suffix is even added.  Keep the node group name short.
      name           = "workers"
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

  # Use the modern Access Entries API exclusively.  No aws-auth ConfigMap.
  # The legacy ConfigMap mode (API_AND_CONFIG_MAP) is a maintenance hazard
  # in a 60-cluster batch: a shell script that patches aws-auth via strategic
  # JSON merge against a YAML-as-string field is fragile and silently fails
  # in ways students notice at the door.  Access Entries are AWS-API-driven,
  # idempotent, and don't depend on kubectl being reachable from the
  # provisioner laptop.
  authentication_mode = "API"

  # Grant the provisioner identity cluster-admin via an automatic access entry.
  enable_cluster_creator_admin_permissions = true

  # Per-student access entries are created post-provision by
  # scripts/create-attendee-users.sh using `aws eks create-access-entry` and
  # `aws eks associate-access-policy AmazonEKSClusterAdminPolicy`.
  access_entries = {}
}
