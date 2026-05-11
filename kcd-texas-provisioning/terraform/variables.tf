variable "region" {
  description = "AWS region for the workshop cluster"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "EKS cluster name.  Each student cluster gets a unique name (e.g., kcd-texas-student-01); batch-provision.sh sets this per-iteration."
  type        = string
  default     = "kcd-texas-workshop"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS.  Check https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for latest supported.  As of May 2026 EKS supports through 1.34 GA."
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes. t3.xlarge = 4 vCPU, 16 GB RAM."
  type        = string
  default     = "t3.xlarge"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to all resources for cost tracking and cleanup"
  type        = map(string)
  default = {
    Project     = "kcd-texas-2026-workshop"
    Environment = "ephemeral"
    Owner       = "platform-engineering"
    Purpose     = "conference-workshop"
  }
}
