terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # For multi-attendee provisioning, use S3 backend with workspaces.
  # Uncomment and configure if needed. Otherwise local state is fine
  # for single-cluster ephemeral use.
  #
  # backend "s3" {
  #   bucket         = "kcd-texas-workshop-tfstate"
  #   key            = "eks/terraform.tfstate"
  #   region         = "us-east-2"
  #   dynamodb_table = "kcd-texas-workshop-locks"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}
