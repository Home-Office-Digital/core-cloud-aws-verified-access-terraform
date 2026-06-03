##-----------------------------------------------------------------------------
## Verified Access Logging - CloudWatch + S3
##-----------------------------------------------------------------------------

##-----------------------------------------------------------------------------
## KMS CMK shared by CloudWatch Logs + primary S3 log bucket
##-----------------------------------------------------------------------------
locals {
  bucket_account_name = lower(replace(var.account_name, "_", "-"))
}
# checkov:skip=CKV_AWS_18 "Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions"
# checkov:skip=CKV_AWS_111 "Ensure IAM policies does not allow write access without constraints"
# checkov:skip=CKV_AWS_109 "Ensure IAM policies does not allow permissions management / resource exposure without constraints"
# checkov:skip=CKV_AWS_356 "Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions"
data "aws_iam_policy_document" "va_logs_kms" {

  # Root account full administration of the key.
  statement {
    sid    = "EnableRootAccountAdmin"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # CloudWatch Logs service principal permissions.
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.region}.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/verified-access/${var.name_prefix}-instance-logs*"
      ]
    }
  }
}
# checkov:skip=CKV_AWS_7 "CMKs key rotation is disabled"
resource "aws_kms_key" "va_logs" {
  description             = "Verified Access logging CMK (CloudWatch + S3)"
  deletion_window_in_days = 30
  enable_key_rotation     = false

  policy = data.aws_iam_policy_document.va_logs_kms.json

  # Required because AWS KMS sometimes incorrectly rejects valid
  # root-admin policies during CreateKey safety validation.
  bypass_policy_lockout_safety_check = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-logs-kms"
  })
}

resource "aws_kms_alias" "va_logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.va_logs.key_id
}

##-----------------------------------------------------------------------------
## CloudWatch Log Group (KMS-encrypted, >=1y retention enforced via var)
##-----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "va_logs" {
  name              = "/aws/verified-access/${var.name_prefix}-instance-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.va_logs.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-log-group"
  })
}

##-----------------------------------------------------------------------------
## S3 server-access-log destination bucket
##-----------------------------------------------------------------------------
# checkov:skip=CKV_AWS_18: Server-access-log destination bucket - logging into itself is not supported.
# checkov:skip=CKV_AWS_144: VA logs are region-local and not subject to multi-region DR.
# checkov:skip=CKV_AWS_145: S3 server access logging delivery does not support SSE-KMS destinations.
# checkov:skip=CKV2_AWS_62: VA log buckets do not require S3 event notifications.
# NOSONAR: Safe by design. This is the destination bucket for server access logs, and S3 does not support logging a destination bucket to itself.
# NOSONAR: Logging is not disabled overall; the primary bucket aws_s3_bucket.va_log_bucket logs to this bucket via aws_s3_bucket_logging.va_logs_access_logging.
resource "aws_s3_bucket" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = "${var.name_prefix}-${local.bucket_account_name}-verified-access-access-logs"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-access-logs"
  })
}

resource "aws_s3_bucket_ownership_controls" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "va_access_logs_https_only" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.va_access_logs[0].arn,
          "${aws_s3_bucket.va_access_logs[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "va_access_logs" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_access_logs[0].id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

##-----------------------------------------------------------------------------
## Primary VA log bucket
##-----------------------------------------------------------------------------
# checkov:skip=CKV_AWS_144: VA logs are region-local and not subject to multi-region DR.
# checkov:skip=CKV2_AWS_62: VA log buckets do not require S3 event notifications.
# checkov:skip=CKV2_AWS_61: VA log buckets has a lifecycle configuration
# NOSONAR: Safe by design. This is the destination bucket for server access logs, and S3 does not support logging a destination bucket to itself.
# NOSONAR: Logging is not disabled overall; the primary bucket aws_s3_bucket.va_log_bucket logs to this bucket via aws_s3_bucket_logging.va_logs_access_logging.
resource "aws_s3_bucket" "va_log_bucket" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = "${var.name_prefix}-${local.bucket_account_name}-verified-access-logs"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-log-bucket"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "va_logs_encryption" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_log_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.va_logs.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "va_logs_block_public" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_log_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "va_log_bucket_https_only" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_log_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.va_log_bucket[0].arn,
          "${aws_s3_bucket.va_log_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "va_logs_versioning" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_log_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "va_logs_access_logging" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket        = aws_s3_bucket.va_log_bucket[0].id
  target_bucket = aws_s3_bucket.va_access_logs[0].id
  target_prefix = "s3-access/${var.name_prefix}-verified-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "va_logs_lifecycle" {
  count = var.use_centralized_log_bucket ? 0 : 1

  bucket = aws_s3_bucket.va_log_bucket[0].id

  rule {
    id     = "archive-old-va-logs"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

##-----------------------------------------------------------------------------
## Verified Access logging configuration
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_instance_logging_configuration" "va_logging" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.main.id

  access_logs {
    include_trust_context = true
    log_version           = "ocsf-1.0.0-rc.2"

    cloudwatch_logs {
      enabled   = true
      log_group = aws_cloudwatch_log_group.va_logs.id
    }

    s3 {
      enabled      = true
      bucket_name  = var.use_centralized_log_bucket ? var.centralized_log_bucket_name : aws_s3_bucket.va_log_bucket[0].id
      bucket_owner = var.use_centralized_log_bucket ? var.centralized_log_bucket_account_id : null
      prefix       = "verified-access-logs"
    }
  }
}