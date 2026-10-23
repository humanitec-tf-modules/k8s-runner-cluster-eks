data "aws_caller_identity" "current" {}

# Random suffix for the fallback IAM role name
resource "random_string" "iam_role_suffix" {
  count   = var.iam_role_create && var.iam_role_name == null ? 1 : 0
  length  = 4
  upper   = false
  numeric = false
  special = false
}

locals {
  # AWS limits IAM role names to 64 characters.
  # Truncate the prefix so the "-" separator and the full random suffix always fit.
  # Kubernetes names only contain characters that IAM allows in role names, so no replacement is needed.
  iam_role_name_max_length = 64
  iam_role_name_prefix = substr(
    join("-", [var.runner_namespace, var.runner_serviceaccount]),
    0,
    local.iam_role_name_max_length - 5
  )

  # Account ID and name of an existing IAM role, parsed from its ARN
  existing_role_arn_parts = var.iam_role_arn != null ? regex(local.iam_role_arn_pattern, var.iam_role_arn) : null

  # Determine the name of the IAM role: from the existing role, the name passed in, or the constructed name
  iam_role_name = (
    !var.iam_role_create
    ? local.existing_role_arn_parts.name
    : var.iam_role_name != null
    ? var.iam_role_name
    : "${local.iam_role_name_prefix}-${random_string.iam_role_suffix[0].result}"
  )

  iam_role_arn       = var.iam_role_create ? aws_iam_role.runner_role[0].arn : data.aws_iam_role.runner_role[0].arn
  iam_role_unique_id = var.iam_role_create ? aws_iam_role.runner_role[0].unique_id : data.aws_iam_role.runner_role[0].unique_id

  # EKS Pod Identity association settings for the runner service account
  pod_identity_association = {
    cluster_name    = var.eks_cluster_name
    namespace       = module.k8s_runner_cluster.runner_namespace
    service_account = module.k8s_runner_cluster.runner_serviceaccount_name
  }

  # Pattern for an IAM role ARN, also used by the iam_role_arn validation
  iam_role_arn_pattern = "^arn:aws[a-z-]*:iam::(?P<account_id>[0-9]{12}):role/(?:[^/]+/)*(?P<name>[\\w+=,.@-]+)$"
}

# Trust policy allowing EKS Pod Identity to assume the runner role
data "aws_iam_policy_document" "runner_pod_identity_trust" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM role and Pod Identity association for the runner
resource "aws_iam_role" "runner_role" {
  count                = var.iam_role_create ? 1 : 0
  name                 = local.iam_role_name
  path                 = var.iam_role_path
  permissions_boundary = var.iam_role_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.runner_pod_identity_trust.json
  tags                 = var.iam_role_tags
}

data "aws_iam_role" "runner_role" {
  count = var.iam_role_create ? 0 : 1
  name  = local.existing_role_arn_parts.name

  lifecycle {
    precondition {
      condition     = local.existing_role_arn_parts.account_id == data.aws_caller_identity.current.account_id
      error_message = "iam_role_arn must be located in the account of the aws provider (${data.aws_caller_identity.current.account_id})."
    }
  }
}

resource "aws_eks_pod_identity_association" "runner_role" {
  count           = var.pod_identity_association_create ? 1 : 0
  cluster_name    = local.pod_identity_association.cluster_name
  namespace       = local.pod_identity_association.namespace
  service_account = local.pod_identity_association.service_account
  role_arn        = local.iam_role_arn
}

# Provision the core Kubernetes setup using the generic module
module "k8s_runner_cluster" {
  # ❌❌ TODO: use tag once available
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster?ref=add-runner-cluster"
  providers = {
    kubernetes = kubernetes
  }

  # Pass through all core variables
  runner_namespace              = var.runner_namespace
  runner_serviceaccount         = var.runner_serviceaccount
  runner_role                   = var.runner_role
  support_kubernetes_tf_backend = var.support_kubernetes_tf_backend
  # EKS Pod Identity does not require an annotation on the service account
  runner_serviceaccount_annotations = var.runner_serviceaccount_annotations
  # Handling for separate runner cluster
  is_separate_runner_cluster       = var.is_separate_runner_cluster
  separate_runner_cluster_subjects = var.separate_runner_cluster_subjects
}
