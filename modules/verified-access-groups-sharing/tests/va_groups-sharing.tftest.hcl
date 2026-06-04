mock_provider "aws" {
  override_during = plan
}

variables {
  verified_access_group_arns = {
    "AWSVerifiedAccess-Platform-App" = "arn:aws:ec2:eu-west-2:111111111111:verified-access-group/vagr-APP12345"
  }

  group_principals = {
    "AWSVerifiedAccess-Platform-App" = [
      "222222222222",
      "333333333333",
      "222222222222",
    ]
    "AWSVerifiedAccess-Platform-Unused" = []
  }

  principal_account_names_by_id = {
    "222222222222" = "platform-dev"
  }
}

run "plans_ram_shares_for_groups_with_consumers" {
  command = plan

  assert {
    condition     = length(output.ram_share_pair_keys) == 2
    error_message = "Expected exactly two deduplicated RAM principal associations."
  }

  assert {
    condition     = output.verified_access_group_ids["AWSVerifiedAccess-Platform-App"] == "vagr-APP12345"
    error_message = "Expected the Verified Access group ID to be parsed from the ARN."
  }

  assert {
    condition     = output.endpoints_config_snippets["platform-dev"]["AWSVerifiedAccess-Platform-App"] == "vagr-APP12345"
    error_message = "Expected endpoints snippet output to pivot IDs by account name."
  }

  assert {
    condition     = !contains(keys(output.ram_share_principals), "AWSVerifiedAccess-Platform-Unused")
    error_message = "Expected groups without consumers to be excluded from RAM outputs."
  }
}

run "rejects_invalid_account_ids" {
  command = plan

  variables {
    group_principals = {
      "AWSVerifiedAccess-Platform-App" = ["invalid-account-id"]
    }
  }

  expect_failures = [
    var.group_principals,
  ]
}

run "skips_groups_without_shareable_targets" {
  command = plan

  variables {
    group_principals = {
      "AWSVerifiedAccess-Platform-App" = []
    }
  }

  assert {
    condition     = length(output.ram_resource_share_arns) == 0
    error_message = "Expected no RAM shares when no group has principals."
  }

  assert {
    condition     = length(output.ram_share_pair_keys) == 0
    error_message = "Expected no group/account association pairs when principal lists are empty."
  }

  assert {
    condition     = length(output.endpoints_config_snippets) == 0
    error_message = "Expected no endpoint snippets when no groups are shared."
  }
}