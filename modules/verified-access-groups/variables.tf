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

variable "policy_documents" {
  description = <<-EOT
    Optional Cedar policy overrides per group, keyed by the group name as it
    appears in var.groups. Any group not present here falls back to the default
    IDC-claim template:

      permit(principal, action, resource)
      when { context.<policy_reference_name>.groups has "<group-name>" };

    Use this when a specific group needs a stricter or different policy (e.g.
    extra context checks like device posture or source IP ranges).
  EOT

  type    = map(string)
  default = {}

  validation {
    condition     = length(setsubtract(keys(var.policy_documents), toset(var.groups))) == 0
    error_message = "policy_documents contains keys that are not in var.groups. Every override must reference a real group."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
