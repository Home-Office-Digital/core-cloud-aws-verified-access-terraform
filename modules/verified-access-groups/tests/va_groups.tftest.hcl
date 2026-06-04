mock_provider "aws" {
  override_during = plan
}

variables {
  verified_access_instance_id = "vai-1234567890abcdef0"
  policy_reference_name       = "corecloud"
  groups = [
    "AWSVerifiedAccess-Platform-App",
    "AWSVerifiedAccess-Platform-RDS",
  ]
  policy_documents = {
    "AWSVerifiedAccess-Platform-RDS" = <<-EOT
      permit(principal, action, resource)
      when {
          principal in [principal]
      };
    EOT
  }
}

run "plans_groups_with_default_and_override_policies" {
  command = plan

  assert {
    condition     = length(output.verified_access_group_names) == 2
    error_message = "Expected two Verified Access groups to be created."
  }

  assert {
    condition     = contains(output.verified_access_group_names, "AWSVerifiedAccess-Platform-App")
    error_message = "Expected the App group name to be present in outputs."
  }

  assert {
    condition     = strcontains(aws_verifiedaccess_group.group["AWSVerifiedAccess-Platform-App"].policy_document, "context.corecloud.groups has \"AWSVerifiedAccess-Platform-App\"")
    error_message = "Expected the App group to use the default Cedar policy template."
  }

  assert {
    condition     = strcontains(aws_verifiedaccess_group.group["AWSVerifiedAccess-Platform-RDS"].policy_document, "principal in [principal]")
    error_message = "Expected the RDS group to use the custom policy override."
  }
}

run "rejects_duplicate_group_names" {
  command = plan

  variables {
    groups = [
      "AWSVerifiedAccess-Platform-App",
      "AWSVerifiedAccess-Platform-App",
    ]
  }

  expect_failures = [
    var.groups,
  ]
}

run "rejects_policy_override_for_unknown_group" {
  command = plan

  variables {
    policy_documents = {
      "AWSVerifiedAccess-Unknown" = <<-EOT
        permit(principal, action, resource);
      EOT
    }
  }

  expect_failures = [
    var.policy_documents,
  ]
}

run "uses_custom_policy_reference_name_in_default_policy" {
  command = plan

  variables {
    policy_reference_name = "customref"
    policy_documents      = {}
  }

  assert {
    condition     = strcontains(aws_verifiedaccess_group.group["AWSVerifiedAccess-Platform-App"].policy_document, "context.customref.groups has \"AWSVerifiedAccess-Platform-App\"")
    error_message = "Expected default policy template to use the provided policy_reference_name value."
  }
}