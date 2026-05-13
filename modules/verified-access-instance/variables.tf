variable "name_prefix" {
  description = "Prefix applied to resources created by this module (instance, trust provider, log bucket, log group)."
  type        = string
  default     = "perimeter-va"
}

variable "policy_reference_name" {
  description = "Reference name for the trust provider used in Verified Access Cedar policies. Consumed by the verified-access-group-share module via remote state."
  type        = string
  default     = "corecloud"
}

variable "enable_waf" {
  description = "Whether to associate an existing WAFv2 Web ACL with the Verified Access instance."
  type        = bool
  default     = false
}

variable "waf_web_acl_name" {
  description = "Name of an existing WAFv2 Web ACL to associate when enable_waf is true."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_waf || length(trimspace(var.waf_web_acl_name)) > 0
    error_message = "waf_web_acl_name must be a non-empty string when enable_waf is true."
  }
}

variable "waf_web_acl_scope" {
  description = "Scope of the existing WAFv2 Web ACL (REGIONAL or CLOUDFRONT)."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], upper(trimspace(var.waf_web_acl_scope)))
    error_message = "waf_web_acl_scope must be either REGIONAL or CLOUDFRONT."
  }
}

variable "use_centralized_log_bucket" {
  description = "When true, write Verified Access S3 logs to a centralized bucket in another account instead of creating a local bucket."
  type        = bool
  default     = false
}

variable "centralized_log_bucket_name" {
  description = "Name of the centralized S3 bucket to receive Verified Access logs when use_centralized_log_bucket is true."
  type        = string
  default     = null
}

variable "centralized_log_bucket_account_id" {
  description = "12-digit AWS account ID that owns centralized_log_bucket_name when use_centralized_log_bucket is true."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Retention in days for the CloudWatch log group used by Verified Access logging. Must be >= 365 to satisfy Checkov CKV_AWS_338 (CloudWatch log groups retain logs for at least 1 year)."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "log_retention_days must be >= 365 days."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "account_name" {
  description = "Account name used for globally unique resource naming."
  type        = string
}
