variable "verified_access_group_arns" {
  description = <<-EOT
    Map of full Verified Access / IAM Identity Center group display name ->
    Verified Access Group ARN. Typically sourced from the verified-access-groups
    module's `verified_access_group_arns` output via Terragrunt remote state.

    Only groups whose name appears as a key in this map are eligible to be
    RAM-shared; entries in var.group_principals whose key is not in this map
    are silently dropped.

    Example:
      verified_access_group_arns = {
        "AWSVerifiedAccess-Platform-App" = "arn:aws:ec2:eu-west-2:111111111111:verified-access-group/vagr-aaaa"
        "AWSVerifiedAccess-Platform-RDS" = "arn:aws:ec2:eu-west-2:111111111111:verified-access-group/vagr-bbbb"
      }
  EOT

  type    = map(string)
  default = {}

  validation {
    condition = alltrue([
      for arn in values(var.verified_access_group_arns) :
      can(regex("^arn:aws[a-zA-Z-]*:ec2:[a-z0-9-]+:[0-9]{12}:verified-access-group/.+$", arn))
    ])
    error_message = "Every value in verified_access_group_arns must be a Verified Access Group ARN."
  }
}

variable "group_principals" {
  description = <<-EOT
    RAM share principals per group, keyed by full group display name. Each
    value is a list of 12-digit AWS account IDs that should receive the
    RAM share for that group's underlying VA group resource. An empty list
    (or a missing key) skips RAM share creation for that group.

    Driven by walking the merged config for accounts where
    verifiedAccessEndpointsAccount=true and adding each such account as a
    principal of every group it lists under verifiedAccessIDCGroupNames.

    Example:
      group_principals = {
        "AWSVerifiedAccess-Platform-App" = ["111111111111", "222222222222"]
        "AWSVerifiedAccess-Platform-RDS" = ["111111111111"]
        "AWSVerifiedAccess-Platform-TCP" = []   # no consumers, no share
      }
  EOT

  type    = map(list(string))
  default = {}

  validation {
    condition = alltrue([
      for _, ids in var.group_principals : alltrue([
        for id in ids : can(regex("^[0-9]{12}$", id))
      ])
    ])
    error_message = "Every entry in group_principals must be a list of 12-digit AWS account IDs."
  }
}

variable "ram_share_name_prefix" {
  description = "Prefix for the aws_ram_resource_share Name. Final name is '<prefix>-<group-name>'."
  type        = string
  default     = "va-group"
}

variable "ram_allow_external_principals" {
  description = "Whether the RAM share allows principals outside the AWS organization. Should remain false for org-internal sharing."
  type        = bool
  default     = false
}

variable "principal_account_names_by_id" {
  description = <<-EOT
    Optional reverse map of 12-digit account ID -> human-readable account name.
    Used purely to label principals in the endpoints_config_snippets output
    so operators can copy/paste verifiedAccessGroupIdsByName into each
    endpoints account's YAML record. Account IDs not present in this map
    are still RAM-shared correctly; they just appear in the snippet output
    under their raw ID instead of their name.
  EOT

  type    = map(string)
  default = {}

  validation {
    condition = alltrue([
      for id in keys(var.principal_account_names_by_id) :
      can(regex("^[0-9]{12}$", id))
    ])
    error_message = "Every key in principal_account_names_by_id must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
