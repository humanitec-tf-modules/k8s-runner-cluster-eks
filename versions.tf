terraform {
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3"
    }
    # 5.34.0 introduced aws_eks_pod_identity_association.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}
