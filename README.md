# EKS Kubernetes runner cluster

This repository contains an OpenTofu/Terraform module to set up an Amazon Elastic Kubernetes Service (EKS) cluster as a runner cluster for the [Container (builtin)](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/container-builtin/) Driver and Drivers based on it such as the [Terraform and OpenTofu Container (builtin)](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/terraform-and-opentofu-container-builtin/) Driver.

> [!NOTE]
> The module does not support the setup of the non-built-in Drivers, including the [Container Runner](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/generic-drivers/container-runner/), [Terraform Runner](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/generic-drivers/terraform-runner/), and [Terraform and OpenTofu Container Runner](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/generic-drivers/terraform-and-opentofu-container-runner/) Drivers.

The module is based on [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) being set up for the target EKS cluster, i.e. the [EKS Pod Identity Agent](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html) add-on being installed. This is the recommended setup for your runners. If you are not using EKS Pod Identity, use the [generic runner cluster module](https://github.com/humanitec-tf-modules/k8s-runner-cluster) instead.

## Usage

### Common usage: Runner cluster is also an Operator cluster

When the runner cluster is also an Operator cluster, you can use all defaults and provide just the essential properties. This configuration creates the Kubernetes namespace, roles, and service account, as well as the AWS IAM role and the EKS Pod Identity association for the runner.

```hcl
module "my_eks_runner_cluster" {
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster-eks?ref=vX.Y.Z"
  providers = {
    kubernetes = kubernetes
  }

  eks_cluster_name = aws_eks_cluster.my_eks_cluster.name
}
```

### Attach policies to the runner role

Use the `iam_role_name` output of the present module to attach IAM policies to the runner role.

```hcl
resource "aws_iam_role_policy_attachment" "runner_s3_full_access" {
  role       = module.my_eks_runner_cluster.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
```

### Annotate the Kubernetes service account and tag the AWS IAM role

```hcl
module "my_eks_runner_cluster" {
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster-eks?ref=vX.Y.Z"
  providers = {
    kubernetes = kubernetes
  }

  eks_cluster_name = aws_eks_cluster.my_eks_cluster.name

  runner_serviceaccount_annotations = {
    "annotation1" = "value1"
    "annotation2" = "value2"
  }
  iam_role_tags = {
    "tag1" = "value1"
    "tag2" = "value2"
  }
}
```

### Bring your own IAM role

This configuration sets up your own AWS IAM role as the runner role. The trust policy of the role must allow EKS Pod Identity to assume it. Use the `iam_role_trust_policy` output of the present module for the required trust policy.

```hcl
module "my_eks_runner_cluster" {
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster-eks?ref=vX.Y.Z"
  providers = {
    kubernetes = kubernetes
  }

  eks_cluster_name = aws_eks_cluster.my_eks_cluster.name

  iam_role_create = false
  iam_role_arn    = aws_iam_role.my_own_runner_role.arn
}
```

### Set up a separate runner cluster

This configuration sets up the required permissions on the Kubernetes cluster to be a separate runner cluster.

```hcl
module "my_eks_runner_cluster" {
  source = "github.com/humanitec-tf-modules/k8s-runner-cluster-eks?ref=vX.Y.Z"
  providers = {
    kubernetes = kubernetes
  }

  eks_cluster_name = aws_eks_cluster.my_eks_cluster.name

  is_separate_runner_cluster = true
  separate_runner_cluster_subjects = [
    {
      kind      = "User"
      name      = "my-user"
      api_group = "rbac.authorization.k8s.io"
    },
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.34.0, < 7.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_k8s_runner_cluster"></a> [k8s\_runner\_cluster](#module\_k8s\_runner\_cluster) | github.com/humanitec-tf-modules/k8s-runner-cluster | add-runner-cluster |

## Resources

| Name | Type |
|------|------|
| [aws_eks_pod_identity_association.runner_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.runner_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [random_string.iam_role_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.runner_pod_identity_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.runner_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | The name of the EKS cluster hosting the runner. Required if `pod_identity_association_create` is `true`. Optional otherwise, if set it is included in the `pod_identity_association` output. | `string` | `null` | no |
| <a name="input_iam_role_arn"></a> [iam\_role\_arn](#input\_iam\_role\_arn) | The ARN of an existing AWS IAM role to be used by the runner. It must be located in the account of the `aws` provider that is passed in to the module, and its trust policy must allow EKS Pod Identity to assume it. Use the `iam_role_trust_policy` output to configure it. Required if `iam_role_create` is `false`, must not be set otherwise | `string` | `null` | no |
| <a name="input_iam_role_create"></a> [iam\_role\_create](#input\_iam\_role\_create) | Whether to create the AWS IAM role used by the runner. If `false`, `iam_role_arn` must be the ARN of an existing IAM role. | `bool` | `true` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the AWS IAM role to create for the runner. Only used if `iam_role_create` is `true`. If not set, the module generates a name from `runner_namespace`, `runner_serviceaccount` and a random four-letter suffix, truncated to 64 characters. | `string` | `null` | no |
| <a name="input_iam_role_path"></a> [iam\_role\_path](#input\_iam\_role\_path) | Path of the AWS IAM role to create for the runner, e.g. `/humanitec/`. If not set, the role is created with the path `/`. Only used if `iam_role_create` is `true`. | `string` | `null` | no |
| <a name="input_iam_role_permissions_boundary_arn"></a> [iam\_role\_permissions\_boundary\_arn](#input\_iam\_role\_permissions\_boundary\_arn) | ARN of the IAM policy to set as the permissions boundary of the AWS IAM role created for the runner. Only used if `iam_role_create` is `true`. | `string` | `null` | no |
| <a name="input_iam_role_tags"></a> [iam\_role\_tags](#input\_iam\_role\_tags) | Tags to assign to the IAM role created by the module. Only used if `iam_role_create` is `true` | `map(string)` | `null` | no |
| <a name="input_is_separate_runner_cluster"></a> [is\_separate\_runner\_cluster](#input\_is\_separate\_runner\_cluster) | Whether the target cluster is a separate runner cluster, i.e. not on the same cluster as an Operator. Setting this to `true` results in an additional role created and bound to the runner service account for managing Kubernetes Jobs and related resources. | `bool` | `false` | no |
| <a name="input_pod_identity_association_create"></a> [pod\_identity\_association\_create](#input\_pod\_identity\_association\_create) | Whether to create the EKS Pod Identity association linking the runner service account to the IAM role. Set to `false` if you manage the association yourself. Use the `pod_identity_association` output to configure it | `bool` | `true` | no |
| <a name="input_runner_namespace"></a> [runner\_namespace](#input\_runner\_namespace) | Name of the Kubernetes namespace for the runner. | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_role"></a> [runner\_role](#input\_runner\_role) | Name of the Kubernetes role for the runner | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_serviceaccount"></a> [runner\_serviceaccount](#input\_runner\_serviceaccount) | Name of the Kubernetes service account for the runner. | `string` | `"humanitec-runner"` | no |
| <a name="input_runner_serviceaccount_annotations"></a> [runner\_serviceaccount\_annotations](#input\_runner\_serviceaccount\_annotations) | Annotations to add to the runner Kubernetes service account. | `map(string)` | `{}` | no |
| <a name="input_separate_runner_cluster_subjects"></a> [separate\_runner\_cluster\_subjects](#input\_separate\_runner\_cluster\_subjects) | Subjects to bind to the additional role created if `is_separate_runner_cluster` is `true`. These are the identities accessing the separate runner cluster, which depend on the technology used for that kind of access. Required to contain at least one subject if `is_separate_runner_cluster` is `true`. | <pre>list(object({<br/>    kind      = string<br/>    name      = string<br/>    api_group = optional(string)<br/>    namespace = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_support_kubernetes_tf_backend"></a> [support\_kubernetes\_tf\_backend](#input\_support\_kubernetes\_tf\_backend) | Whether to support a `kubernetes` OpenTofu/Terraform backend for the runner. Setting this to `true` adds extended permissions to the role for the runner service account. If not required, leave it at `false` to maintain least privilege. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_account_id"></a> [aws\_account\_id](#output\_aws\_account\_id) | ID of the AWS account of the IAM role |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role used by the runner |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the IAM role used by the runner. Use it to attach IAM policies to the role |
| <a name="output_iam_role_trust_policy"></a> [iam\_role\_trust\_policy](#output\_iam\_role\_trust\_policy) | Trust policy allowing EKS Pod Identity to assume the IAM role, in JSON format. If `iam_role_create` is `false`, configure this trust policy on the IAM role yourself |
| <a name="output_iam_role_unique_id"></a> [iam\_role\_unique\_id](#output\_iam\_role\_unique\_id) | Stable and unique ID of the IAM role used by the runner |
| <a name="output_pod_identity_association"></a> [pod\_identity\_association](#output\_pod\_identity\_association) | Cluster name, namespace, and service account of the EKS Pod Identity association allowing the runner to use the IAM role. If `pod_identity_association_create` is `false`, configure an association with these values and the `iam_role_arn` yourself |
| <a name="output_pod_identity_association_id"></a> [pod\_identity\_association\_id](#output\_pod\_identity\_association\_id) | ID of the EKS Pod Identity association created by the module, or `null` if `pod_identity_association_create` is `false` |
| <a name="output_runner_namespace"></a> [runner\_namespace](#output\_runner\_namespace) | Name of the Kubernetes namespace for the runner. |
| <a name="output_runner_role_name"></a> [runner\_role\_name](#output\_runner\_role\_name) | Name of the Kubernetes role for the runner. |
| <a name="output_runner_rolebinding_name"></a> [runner\_rolebinding\_name](#output\_runner\_rolebinding\_name) | Name of the Kubernetes rolebinding for the runner. |
| <a name="output_runner_serviceaccount_name"></a> [runner\_serviceaccount\_name](#output\_runner\_serviceaccount\_name) | Name of the Kubernetes service account for the runner. |
| <a name="output_separate_runner_cluster_role_name"></a> [separate\_runner\_cluster\_role\_name](#output\_separate\_runner\_cluster\_role\_name) | Name of the Kubernetes role created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise. |
| <a name="output_separate_runner_cluster_rolebinding_name"></a> [separate\_runner\_cluster\_rolebinding\_name](#output\_separate\_runner\_cluster\_rolebinding\_name) | Name of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`. Returns `null` otherwise. |
| <a name="output_separate_runner_cluster_rolebinding_subjects"></a> [separate\_runner\_cluster\_rolebinding\_subjects](#output\_separate\_runner\_cluster\_rolebinding\_subjects) | Subjects of the Kubernetes rolebinding created if `is_separate_runner_cluster` is `true`, including any attributes filled in by the provider. Returns `null` otherwise. |
<!-- END_TF_DOCS -->
