variable "name_prefix" {
  description = "Prefix applied to endpoint resource Name tags."
  type        = string
  default     = "workload-va"
}

variable "vpc_name" {
  description = "Name tag of the workload VPC."
  type        = string
}

variable "default_certificate_domain" {
  description = "Wildcard ACM certificate domain for web/load-balancer endpoints."
  type        = string
  default     = null
}

variable "verified_access_group_ids_by_name" {
  description = "Map of Verified Access group display name to Verified Access group ID."
  type        = map(string)
  default     = {}
}

variable "endpoints" {
  description = <<-EOT
    Map of Verified Access endpoints, keyed by a stable name (typically
    "<category>__<endpoint>").

    endpoint_type is optional in the type so the caller can omit it when
    load_balancer_name alone is enough to infer it; the validation below
    requires it to resolve to one of the supported types in the end.
  EOT

  type = map(object({
    group_name             = string
    endpoint_type          = optional(string)
    application_domain     = optional(string)
    endpoint_domain_prefix = optional(string)
    description            = optional(string)
    policy_document        = optional(string)
    load_balancer_name     = optional(string)
    port                   = optional(number)
    cert_domain_name       = optional(string)

    cidr_options = optional(object({
      cidr         = string
      protocol     = string
      subnet_names = list(string)
      port_range = object({
        from = number
        to   = number
      })
    }))
  }))

  default = {}

  validation {
    condition = alltrue([
      for _, e in var.endpoints :
      e.endpoint_type != null && contains(["load-balancer", "cidr"], e.endpoint_type)
    ])
    error_message = "Every endpoint must set endpoint_type to one of: load-balancer, cidr. (For load-balancer endpoints with loadBalancerName set, the platform terragrunt entry will default endpoint_type to 'load-balancer' if you omit it.)"
  }
}

variable "tags" {
  description = "Tags applied to all endpoint resources."
  type        = map(string)
  default     = {}
}