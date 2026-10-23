output "runner_namespace" {
  description = "Name of the Kubernetes namespace for the runner."
  value       = module.k8s_runner_cluster.runner_namespace
}
output "runner_serviceaccount_name" {
  description = "Name of the Kubernetes service account for the runner."
  value       = module.k8s_runner_cluster.runner_serviceaccount_name
}
output "runner_role_name" {
  description = "Name of the Kubernetes role for the runner."
  value       = module.k8s_runner_cluster.runner_role_name
}
output "runner_rolebinding_name" {
  description = "Name of the Kubernetes rolebinding for the runner."
  value       = module.k8s_runner_cluster.runner_rolebinding_name
}
output "separate_runner_cluster_role_name" {
  description = "Name of the Kubernetes role created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_role_name
}
output "separate_runner_cluster_rolebinding_name" {
  description = "Name of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_rolebinding_name
}
output "separate_runner_cluster_rolebinding_subjects" {
  description = "Subjects of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`, including any attributes filled in by the provider. Returns `null` otherwise."
  value       = module.k8s_runner_cluster.separate_runner_cluster_rolebinding_subjects
}
output "iam_role_arn" {
  value       = local.iam_role_arn
  description = "ARN of the IAM role used by the runner"
}
output "iam_role_name" {
  value       = local.iam_role_actual_name
  description = "Name of the IAM role used by the runner. Use it to attach IAM policies to the role"
}
output "iam_role_unique_id" {
  value       = local.iam_role_unique_id
  description = "Stable and unique ID of the IAM role used by the runner"
}
output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "ID of the AWS account of the IAM role"
}
output "iam_role_trust_policy" {
  value       = data.aws_iam_policy_document.runner_pod_identity_trust.json
  description = "Trust policy allowing EKS Pod Identity to assume the IAM role, in JSON format. If `iam_role_create` is `false`, configure this trust policy on the IAM role yourself"
}
output "pod_identity_association_id" {
  value       = one(aws_eks_pod_identity_association.runner_role[*].association_id)
  description = "ID of the EKS Pod Identity association created by the module, or `null` if `pod_identity_association_create` is `false`"
}
output "pod_identity_association" {
  value       = local.pod_identity_association
  description = "Cluster name, namespace, and service account of the EKS Pod Identity association allowing the runner to use the IAM role. If `pod_identity_association_create` is `false`, configure an association with these values and the `iam_role_arn` yourself"
}
