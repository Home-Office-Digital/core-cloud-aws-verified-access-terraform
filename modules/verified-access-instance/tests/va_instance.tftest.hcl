mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "eu-west-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:eu-west-2:111111111111:regional/webacl/perimeter-acl/mock"
    }
  }
}

override_data {
  target = data.aws_iam_policy_document.va_logs_kms
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

variables {
  account_name = "platform_shared"
}

run "plans_instance_and_logging_resources" {
  command = plan

  assert {
    condition     = output.trust_provider_policy_reference_name == "corecloud"
    error_message = "Expected the trust provider policy reference name output to match the default."
  }

  assert {
    condition     = aws_cloudwatch_log_group.va_logs.retention_in_days == 365
    error_message = "Expected the CloudWatch log group retention to default to 365 days."
  }

  assert {
    condition     = aws_s3_bucket.va_log_bucket[0].bucket == "perimeter-va-platform-shared-verified-access-logs"
    error_message = "Expected the primary log bucket name to be normalized from account_name."
  }

  assert {
    condition     = aws_s3_bucket.va_access_logs[0].bucket == "perimeter-va-platform-shared-verified-access-access-logs"
    error_message = "Expected the access log bucket name to be normalized from account_name."
  }
}

run "rejects_short_log_retention" {
  command = plan

  variables {
    log_retention_days = 30
  }

  expect_failures = [
    var.log_retention_days,
  ]
}

run "skips_local_buckets_when_centralized_logging_enabled" {
  command = plan

  variables {
    use_centralized_log_bucket        = true
    centralized_log_bucket_name       = "centralized-va-logs"
    centralized_log_bucket_account_id = "111111111111"
  }

  assert {
    condition     = length(aws_s3_bucket.va_log_bucket) == 0
    error_message = "Expected local primary log bucket to be skipped when centralized logging is enabled."
  }

  assert {
    condition     = length(aws_s3_bucket.va_access_logs) == 0
    error_message = "Expected local access log bucket to be skipped when centralized logging is enabled."
  }
}

run "creates_waf_association_when_enabled" {
  command = plan

  variables {
    enable_waf        = true
    waf_web_acl_name  = "perimeter-acl"
    waf_web_acl_scope = "REGIONAL"
  }

  assert {
    condition     = length(aws_wafv2_web_acl_association.va_assoc) == 1
    error_message = "Expected one WAF association when enable_waf is true."
  }
}

run "does_not_create_waf_association_by_default" {
  command = plan

  assert {
    condition     = length(aws_wafv2_web_acl_association.va_assoc) == 0
    error_message = "Expected no WAF association when enable_waf is not set."
  }
}