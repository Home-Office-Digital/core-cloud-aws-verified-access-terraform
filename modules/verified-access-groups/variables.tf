variable "verified_access_instance_id" {
  description = "ID of the Verified Access Instance to attach groups to. Sourced from the verified-access-instance module via Terragrunt remote state."
  type        = string
}

variable "policy_reference_name" {
  description = "Trust provider policy_reference_name to use in each group's Cedar policy (e.g. context.<this>.groups). Sourced from the verified-access-instance module via Terragrunt remote state."
  type        = string
  default     = "corecloud"
}

variable "groups" {
  description = <<-EOT
    List of full Verified Access / IAM Identity Center group display names.
    Each entry produces one Verified Access Group whose Name tag equals the
    entry, and whose Cedar policy permits principals when
    context.<policy_reference_name>.groups contains the same string.

    Example:
      groups = [
        "AWSVerifiedAccess-Platform-App",
        "AWSVerifiedAccess-Platform-RDS",
      ]
  EOT

  type    = list(string)
  default = []

  validation {
    condition     = length(var.groups) == length(distinct(var.groups))
    error_message = "Each entry in var.groups must be unique."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
