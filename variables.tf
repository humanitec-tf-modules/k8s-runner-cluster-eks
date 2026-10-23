variable "runner_namespace" {
  description = "Name of the Kubernetes namespace for the runner."
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "runner_serviceaccount" {
  description = "Name of the Kubernetes service account for the runner."
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "runner_serviceaccount_annotations" {
  description = "Annotations to add to the runner Kubernetes service account."
  type        = map(string)
  nullable    = false
  default     = {}
}
variable "runner_role" {
  description = "Name of the Kubernetes role for the runner"
  type        = string
  nullable    = false
  default     = "humanitec-runner"
}
variable "support_kubernetes_tf_backend" {
  description = "Whether to support a `kubernetes` OpenTofu/Terraform backend for the runner. Setting this to `true` adds extended permissions to the role for the runner service account. If not required, leave it at `false` to maintain least privilege."
  type        = bool
  nullable    = false
  default     = false
}
variable "is_separate_runner_cluster" {
  description = "Whether the target cluster is a separate runner cluster, i.e. not on the same cluster as an Operator. Setting this to `true` results in an additional role created and bound to the runner service account for managing Kubernetes Jobs and related resources."
  type        = bool
  nullable    = false
  default     = false
}
variable "separate_runner_cluster_subjects" {
  description = "Subjects to bind to the additional role created if `is_separate_runner_cluster` is `true`. These are the identities accessing the separate runner cluster, which depend on the technology used for that kind of access. Required to contain at least one subject if `is_separate_runner_cluster` is `true`."
  type = list(object({
    kind      = string
    name      = string
    api_group = optional(string)
    namespace = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition     = !var.is_separate_runner_cluster || length(var.separate_runner_cluster_subjects) > 0
    error_message = "separate_runner_cluster_subjects must contain at least one subject if is_separate_runner_cluster is true."
  }
}
variable "iam_role_create" {
  type        = bool
  description = "Whether to create the AWS IAM role used by the runner. If `false`, `iam_role_arn` must be the ARN of an existing IAM role."
  nullable    = false
  default     = true
}
variable "iam_role_name" {
  description = "Name of the AWS IAM role to create for the runner. Only used if `iam_role_create` is `true`. If not set, the module generates a name from `runner_namespace`, `runner_serviceaccount` and a random four-letter suffix, truncated to 64 characters."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.iam_role_create || var.iam_role_name == null
    error_message = "iam_role_name must not be set if iam_role_create is false. Use iam_role_arn to pass in an existing IAM role"
  }
}
variable "iam_role_path" {
  description = "Path of the AWS IAM role to create for the runner, e.g. `/humanitec/`. If not set, the role is created with the path `/`. Only used if `iam_role_create` is `true`."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.iam_role_create || var.iam_role_path == null
    error_message = "iam_role_path must not be set if iam_role_create is false"
  }

  validation {
    condition     = var.iam_role_path == null || can(regex("^/(?:[^/]+/)*$", var.iam_role_path))
    error_message = "iam_role_path must begin and end with a forward slash, e.g. /humanitec/"
  }
}
variable "iam_role_permissions_boundary_arn" {
  description = "ARN of the IAM policy to set as the permissions boundary of the AWS IAM role created for the runner. Only used if `iam_role_create` is `true`."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.iam_role_create || var.iam_role_permissions_boundary_arn == null
    error_message = "iam_role_permissions_boundary_arn must not be set if iam_role_create is false"
  }
}
variable "iam_role_tags" {
  type        = map(string)
  description = "Tags to assign to the IAM role created by the module. Only used if `iam_role_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.iam_role_create || var.iam_role_tags == null
    error_message = "iam_role_tags must not be set if iam_role_create is false"
  }
}
variable "iam_role_arn" {
  type        = string
  description = "The ARN of an existing AWS IAM role to be used by the runner. It must be located in the account of the `aws` provider that is passed in to the module, and its trust policy must allow EKS Pod Identity to assume it. Use the `iam_role_trust_policy` output to configure it. Required if `iam_role_create` is `false`, must not be set otherwise"
  nullable    = true
  default     = null

  validation {
    condition     = var.iam_role_create ? var.iam_role_arn == null : var.iam_role_arn != null
    error_message = "iam_role_arn must be set if iam_role_create is false, and must not be set otherwise"
  }

  validation {
    condition     = var.iam_role_arn == null || can(regex(local.iam_role_arn_pattern, var.iam_role_arn))
    error_message = "iam_role_arn must be an IAM role ARN like arn:aws:iam::123456789012:role/my-role"
  }
}
variable "pod_identity_association_create" {
  type        = bool
  description = "Whether to create the EKS Pod Identity association linking the runner service account to the IAM role. Set to `false` if you manage the association yourself. Use the `pod_identity_association` output to configure it"
  nullable    = false
  default     = true
}
variable "eks_cluster_name" {
  description = "The name of the EKS cluster hosting the runner. Required if `pod_identity_association_create` is `true`. Optional otherwise, if set it is included in the `pod_identity_association` output."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = !var.pod_identity_association_create || var.eks_cluster_name != null
    error_message = "eks_cluster_name must be set when pod_identity_association_create is true"
  }
}
