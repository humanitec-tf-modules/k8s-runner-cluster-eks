# Mock all providers so the tests run without access to AWS or a Kubernetes cluster
mock_provider "kubernetes" {}
mock_provider "random" {
  # The mocked result does not honor the length attribute
  mock_resource "random_string" {
    defaults = {
      result = "abcd"
    }
  }
}
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  # The mocked policy document does not render its statements
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\"}"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:role/created-role"
      unique_id = "AROA11111111111111111"
    }
  }
  mock_data "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:role/existing-path/existing-role"
      unique_id = "AROA22222222222222222"
    }
  }
  mock_resource "aws_eks_pod_identity_association" {
    defaults = {
      association_id = "a-0000000000000000"
    }
  }
}

# The minimum set of variables
variables {
  eks_cluster_name = "my-cluster"
}

# Default case

run "defaults" {
  # The random suffix of the generated name is only known after apply
  command = apply

  # IAM role
  assert {
    condition     = length(aws_iam_role.runner_role) == 1
    error_message = "IAM role should be created by default"
  }
  assert {
    condition     = length(data.aws_iam_role.runner_role) == 0
    error_message = "No existing IAM role should be read by default"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].name == "humanitec-runner-humanitec-runner-abcd"
    error_message = "IAM role name should be generated as <namespace>-<serviceaccount>-<suffix>, got ${aws_iam_role.runner_role[0].name}"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].path == null && aws_iam_role.runner_role[0].permissions_boundary == null
    error_message = "IAM role should have no custom path and no permissions boundary by default"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].tags == null
    error_message = "IAM role should have no tags by default"
  }

  # Trust policy
  assert {
    condition     = aws_iam_role.runner_role[0].assume_role_policy == data.aws_iam_policy_document.runner_pod_identity_trust.json
    error_message = "IAM role should use the Pod Identity trust policy"
  }
  assert {
    condition = (
      length(data.aws_iam_policy_document.runner_pod_identity_trust.statement) == 1 &&
      data.aws_iam_policy_document.runner_pod_identity_trust.statement[0].effect == "Allow" &&
      toset(data.aws_iam_policy_document.runner_pod_identity_trust.statement[0].actions) == toset(["sts:AssumeRole", "sts:TagSession"])
    )
    error_message = "Trust policy should allow sts:AssumeRole and sts:TagSession"
  }
  assert {
    condition = [for p in data.aws_iam_policy_document.runner_pod_identity_trust.statement[0].principals : {
      type        = p.type
      identifiers = toset(p.identifiers)
    }] == [{ type = "Service", identifiers = toset(["pods.eks.amazonaws.com"]) }]
    error_message = "Trust policy should trust the EKS Pod Identity service principal"
  }

  # Pod Identity association
  assert {
    condition     = length(aws_eks_pod_identity_association.runner_role) == 1
    error_message = "Pod Identity association should be created by default"
  }
  assert {
    condition     = aws_eks_pod_identity_association.runner_role[0].role_arn == aws_iam_role.runner_role[0].arn
    error_message = "Pod Identity association should use the new IAM role"
  }
  assert {
    condition     = aws_eks_pod_identity_association.runner_role[0].cluster_name == "my-cluster"
    error_message = "Pod Identity association should be created in eks_cluster_name"
  }
  assert {
    condition = (
      aws_eks_pod_identity_association.runner_role[0].namespace == "humanitec-runner" &&
      aws_eks_pod_identity_association.runner_role[0].service_account == "humanitec-runner"
    )
    error_message = "Pod Identity association should be for the runner service account"
  }

  # Outputs
  assert {
    condition = (
      output.runner_namespace == "humanitec-runner" &&
      output.runner_serviceaccount_name == "humanitec-runner" &&
      output.runner_role_name == "humanitec-runner" &&
      output.runner_rolebinding_name == "humanitec-runner"
    )
    error_message = "Kubernetes namespace, service account, role and rolebinding outputs should use the default names"
  }
  assert {
    condition = (
      output.separate_runner_cluster_role_name == null &&
      output.separate_runner_cluster_rolebinding_name == null &&
      output.separate_runner_cluster_rolebinding_subjects == null
    )
    error_message = "Separate runner cluster role, rolebinding and subjects outputs should be null by default"
  }
  assert {
    condition = (
      output.iam_role_arn == "arn:aws:iam::123456789012:role/created-role" &&
      output.iam_role_name == "humanitec-runner-humanitec-runner-abcd"
    )
    error_message = "IAM role ARN and name outputs should be those of the new IAM role"
  }
  assert {
    condition     = output.iam_role_unique_id == "AROA11111111111111111"
    error_message = "IAM role unique ID output should be that of the new IAM role"
  }
  assert {
    condition     = length(module.k8s_runner_cluster.runner_serviceaccount_annotations) == 0
    error_message = "Runner service account should not be annotated by default"
  }
  assert {
    condition     = output.aws_account_id == "123456789012"
    error_message = "AWS account ID output should be the account of the aws provider"
  }
  assert {
    condition     = output.iam_role_trust_policy == data.aws_iam_policy_document.runner_pod_identity_trust.json
    error_message = "IAM role trust policy output should be the Pod Identity trust policy"
  }
  assert {
    condition     = output.pod_identity_association_id == "a-0000000000000000"
    error_message = "Pod Identity association ID output should be the ID of the created association"
  }
  assert {
    condition = output.pod_identity_association == {
      cluster_name    = "my-cluster"
      namespace       = "humanitec-runner"
      service_account = "humanitec-runner"
    }
    error_message = "Pod Identity association output should contain the cluster name, namespace and service account of the runner"
  }
  assert {
    condition = (
      output.pod_identity_association.cluster_name == aws_eks_pod_identity_association.runner_role[0].cluster_name &&
      output.pod_identity_association.namespace == aws_eks_pod_identity_association.runner_role[0].namespace &&
      output.pod_identity_association.service_account == aws_eks_pod_identity_association.runner_role[0].service_account
    )
    error_message = "Pod Identity association output should match the created association"
  }
}

# Complete cases

run "complete_create_role" {
  command = apply

  variables {
    runner_namespace                  = "platform-runner"
    runner_serviceaccount             = "runner-sa"
    runner_serviceaccount_annotations = { "example.com/team" = "platform" }
    runner_role                       = "runner-role"
    support_kubernetes_tf_backend     = true
    is_separate_runner_cluster        = true
    separate_runner_cluster_subjects = [
      {
        kind      = "ServiceAccount"
        name      = "my-serviceaccount"
        namespace = "my-namespace"
      },
      {
        kind      = "Group"
        name      = "my-group"
        api_group = "rbac.authorization.k8s.io"
      },
      {
        kind = "User"
        name = "my-user"
      },
    ]
    iam_role_create                   = true
    iam_role_name                     = "my-role"
    iam_role_path                     = "/humanitec/"
    iam_role_permissions_boundary_arn = "arn:aws:iam::123456789012:policy/my-boundary"
    iam_role_tags                     = { env = "test" }
    pod_identity_association_create   = true
    eks_cluster_name                  = "my-cluster"
  }

  # IAM role
  assert {
    condition     = length(random_string.iam_role_suffix) == 0
    error_message = "No random suffix should be generated for a custom IAM role name"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].name == "my-role"
    error_message = "IAM role should use iam_role_name"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].path == "/humanitec/"
    error_message = "IAM role should use iam_role_path"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].permissions_boundary == "arn:aws:iam::123456789012:policy/my-boundary"
    error_message = "IAM role should use iam_role_permissions_boundary_arn"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].tags == tomap({ env = "test" })
    error_message = "IAM role should use iam_role_tags"
  }

  # Pod Identity association
  assert {
    condition = (
      aws_eks_pod_identity_association.runner_role[0].namespace == "platform-runner" &&
      aws_eks_pod_identity_association.runner_role[0].service_account == "runner-sa"
    )
    error_message = "Pod Identity association should use the custom namespace and service account"
  }

  # Outputs
  assert {
    condition = (
      output.runner_namespace == "platform-runner" &&
      output.runner_serviceaccount_name == "runner-sa" &&
      output.runner_role_name == "runner-role" &&
      output.runner_rolebinding_name == "runner-role"
    )
    error_message = "Kubernetes namespace, service account, role and rolebinding outputs should use the custom names"
  }
  assert {
    condition     = output.separate_runner_cluster_role_name == "runner-role-separate-cluster" && output.separate_runner_cluster_rolebinding_name == "runner-role-separate-cluster"
    error_message = "Separate runner cluster role and rolebinding should be created if is_separate_runner_cluster is true"
  }
  assert {
    condition = [for s in output.separate_runner_cluster_rolebinding_subjects : { kind = s.kind, name = s.name }] == [
      { kind = "ServiceAccount", name = "my-serviceaccount" },
      { kind = "Group", name = "my-group" },
      { kind = "User", name = "my-user" },
    ]
    error_message = "Separate runner cluster rolebinding should bind exactly the separate_runner_cluster_subjects, in order"
  }
  assert {
    condition     = output.separate_runner_cluster_rolebinding_subjects[0].namespace == "my-namespace"
    error_message = "Separate runner cluster rolebinding should pass on the namespace of a subject"
  }
  assert {
    condition     = output.separate_runner_cluster_rolebinding_subjects[1].api_group == "rbac.authorization.k8s.io"
    error_message = "Separate runner cluster rolebinding should pass on the api_group of a subject"
  }
  assert {
    condition     = output.iam_role_name == "my-role"
    error_message = "IAM role name output should be iam_role_name"
  }
  assert {
    condition     = module.k8s_runner_cluster.runner_serviceaccount_annotations == tomap({ "example.com/team" = "platform" })
    error_message = "Runner service account should be annotated with exactly runner_serviceaccount_annotations"
  }
  assert {
    condition = output.pod_identity_association == {
      cluster_name    = "my-cluster"
      namespace       = "platform-runner"
      service_account = "runner-sa"
    }
    error_message = "Pod Identity association output should use the custom namespace and service account"
  }
}

run "complete_existing_role" {
  command = apply

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:role/existing-path/existing-role"
  }

  # IAM role
  assert {
    condition     = length(aws_iam_role.runner_role) == 0
    error_message = "IAM role should not be created if iam_role_create is false"
  }
  assert {
    condition     = length(random_string.iam_role_suffix) == 0
    error_message = "No random suffix should be generated for an existing IAM role"
  }
  assert {
    condition     = data.aws_iam_role.runner_role[0].name == "existing-role"
    error_message = "Existing IAM role should be read by the name in iam_role_arn"
  }

  # Pod Identity association
  assert {
    condition     = aws_eks_pod_identity_association.runner_role[0].role_arn == var.iam_role_arn
    error_message = "Pod Identity association should use the existing IAM role"
  }

  # Outputs
  assert {
    condition = (
      output.iam_role_arn == var.iam_role_arn &&
      output.iam_role_name == "existing-role"
    )
    error_message = "IAM role ARN and name outputs should be those of the existing IAM role"
  }
  assert {
    condition     = output.iam_role_unique_id == "AROA22222222222222222"
    error_message = "IAM role unique ID output should be that of the existing IAM role"
  }
  assert {
    condition     = length(module.k8s_runner_cluster.runner_serviceaccount_annotations) == 0
    error_message = "Runner service account should not be annotated for an existing IAM role"
  }
  assert {
    condition     = output.iam_role_trust_policy == data.aws_iam_policy_document.runner_pod_identity_trust.json
    error_message = "IAM role trust policy output should be provided to configure an existing IAM role"
  }
  assert {
    condition     = output.pod_identity_association_id == aws_eks_pod_identity_association.runner_role[0].association_id
    error_message = "Pod Identity association ID output should be the ID of the created association"
  }
}

# Edge cases

run "generated_name_is_truncated" {
  command = apply

  variables {
    runner_namespace      = join("", [for i in range(40) : "n"])
    runner_serviceaccount = "s.${join("", [for i in range(38) : "s"])}"
  }

  assert {
    condition     = length(aws_iam_role.runner_role[0].name) == 64
    error_message = "Generated IAM role name should be truncated to 64 characters, got ${length(aws_iam_role.runner_role[0].name)}"
  }
  assert {
    condition     = aws_iam_role.runner_role[0].name == "${join("", [for i in range(40) : "n"])}-s.${join("", [for i in range(16) : "s"])}-abcd"
    error_message = "Generated IAM role name should keep dots and the full random suffix, got ${aws_iam_role.runner_role[0].name}"
  }
}

run "existing_role_without_path" {
  command = apply

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:role/existing-role"
  }

  assert {
    condition     = data.aws_iam_role.runner_role[0].name == "existing-role"
    error_message = "Existing IAM role should be read from an ARN without path"
  }
}

run "existing_role_in_other_partition" {
  command = apply

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws-us-gov:iam::123456789012:role/existing-role"
  }

  assert {
    condition     = data.aws_iam_role.runner_role[0].name == "existing-role"
    error_message = "Existing IAM role should be read from an ARN in a partition other than aws"
  }
}

run "create_role_without_association" {
  command = apply

  # eks_cluster_name is still set from the file-level variables
  variables {
    pod_identity_association_create = false
  }

  assert {
    condition     = length(aws_iam_role.runner_role) == 1
    error_message = "IAM role should be created"
  }
  assert {
    condition     = length(aws_eks_pod_identity_association.runner_role) == 0
    error_message = "Pod Identity association should not be created if pod_identity_association_create is false"
  }
  assert {
    condition     = output.pod_identity_association_id == null
    error_message = "Pod Identity association ID output should be null if no association is created"
  }
  assert {
    condition     = output.iam_role_arn == "arn:aws:iam::123456789012:role/created-role"
    error_message = "IAM role ARN output should be set without a Pod Identity association"
  }
  assert {
    condition = output.pod_identity_association == {
      cluster_name    = "my-cluster"
      namespace       = "humanitec-runner"
      service_account = "humanitec-runner"
    }
    error_message = "Pod Identity association output should provide the cluster name, namespace and service account to configure an association yourself"
  }
}

run "existing_role_without_association" {
  command = apply

  variables {
    iam_role_create                 = false
    iam_role_arn                    = "arn:aws:iam::123456789012:role/existing-path/existing-role"
    pod_identity_association_create = false
    eks_cluster_name                = null
  }

  assert {
    condition     = length(aws_iam_role.runner_role) == 0 && length(aws_eks_pod_identity_association.runner_role) == 0
    error_message = "Neither an IAM role nor a Pod Identity association should be created"
  }
  assert {
    condition     = output.pod_identity_association_id == null
    error_message = "Pod Identity association ID output should be null if no association is created"
  }
  assert {
    condition     = output.iam_role_arn == "arn:aws:iam::123456789012:role/existing-path/existing-role"
    error_message = "IAM role ARN output should be that of the existing IAM role"
  }
  assert {
    condition = (
      output.pod_identity_association.cluster_name == null &&
      output.pod_identity_association.namespace == "humanitec-runner" &&
      output.pod_identity_association.service_account == "humanitec-runner"
    )
    error_message = "Pod Identity association output should provide the namespace and service account, and no cluster name if eks_cluster_name is not set"
  }
}

# Validation failures

run "separate_runner_cluster_requires_subjects" {
  command = plan

  variables {
    is_separate_runner_cluster = true
  }

  expect_failures = [var.separate_runner_cluster_subjects]
}

run "create_role_rejects_iam_role_arn" {
  command = plan

  variables {
    iam_role_arn = "arn:aws:iam::123456789012:role/existing-role"
  }

  expect_failures = [var.iam_role_arn]
}

run "create_role_rejects_invalid_path" {
  command = plan

  variables {
    iam_role_path = "humanitec"
  }

  expect_failures = [var.iam_role_path]
}

run "association_requires_eks_cluster_name" {
  command = plan

  variables {
    eks_cluster_name = null
  }

  expect_failures = [var.eks_cluster_name]
}

run "existing_role_requires_iam_role_arn" {
  command = plan

  variables {
    iam_role_create = false
  }

  expect_failures = [var.iam_role_arn]
}

run "existing_role_rejects_invalid_iam_role_arn" {
  command = plan

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:policy/existing-policy"
  }

  expect_failures = [var.iam_role_arn]
}

run "existing_role_rejects_other_account" {
  command = plan

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::210987654321:role/existing-role"
  }

  expect_failures = [data.aws_iam_role.runner_role]
}

run "existing_role_rejects_name" {
  command = plan

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:role/existing-role"
    iam_role_name   = "my-role"
  }

  expect_failures = [var.iam_role_name]
}

run "existing_role_rejects_path" {
  command = plan

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:role/existing-role"
    iam_role_path   = "/humanitec/"
  }

  expect_failures = [var.iam_role_path]
}

run "existing_role_rejects_permissions_boundary" {
  command = plan

  variables {
    iam_role_create                   = false
    iam_role_arn                      = "arn:aws:iam::123456789012:role/existing-role"
    iam_role_permissions_boundary_arn = "arn:aws:iam::123456789012:policy/my-boundary"
  }

  expect_failures = [var.iam_role_permissions_boundary_arn]
}

run "existing_role_rejects_tags" {
  command = plan

  variables {
    iam_role_create = false
    iam_role_arn    = "arn:aws:iam::123456789012:role/existing-role"
    iam_role_tags   = { env = "test" }
  }

  expect_failures = [var.iam_role_tags]
}
