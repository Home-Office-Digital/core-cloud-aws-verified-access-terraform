output "endpoint_ids" {
  description = "Map of endpoint name to Verified Access endpoint ID."
  value       = { for k, e in aws_verifiedaccess_endpoint.this : k => e.id }
}

output "endpoint_domains" {
  description = "Map of endpoint name to AWS-generated Verified Access endpoint domain. Use this as the CNAME target."
  value       = { for k, e in aws_verifiedaccess_endpoint.this : k => e.endpoint_domain }
}

output "application_domains" {
  description = "Map of endpoint name to configured application domain. CIDR endpoints return null."
  value       = { for k, e in local.endpoints : k => try(e.application_domain, null) }
}

output "endpoint_types" {
  description = "Map of endpoint name to endpoint type."
  value       = { for k, e in local.endpoints : k => e.endpoint_type }
}

output "default_certificate_arn" {
  description = "ARN of the default ACM certificate looked up via var.default_certificate_domain."
  value       = local.default_cert_arn
}

output "security_group_ids" {
  description = "Map of endpoint name to the per-endpoint security group ID."
  value       = { for k, sg in aws_security_group.endpoint : k => sg.id }
}

output "vpc_id" {
  description = "ID of the workload VPC resolved from var.vpc_name."
  value       = local.vpc_id
}

output "group_id_by_name" {
  description = "Map of group display name to Verified Access group ID passed into the module."
  value       = var.verified_access_group_ids_by_name
}

output "load_balancer_arns" {
  description = "Map of load-balancer endpoint name to resolved load balancer ARN."
  value       = { for k, e in local.endpoints : k => e.load_balancer_arn if e.endpoint_type == "load-balancer" }
}

output "load_balancer_subnet_ids" {
  description = "Map of load-balancer endpoint name to resolved load balancer subnet IDs."
  value       = { for k, e in local.endpoints : k => e.lb_subnet_ids if e.endpoint_type == "load-balancer" }
}

output "cidr_subnet_ids" {
  description = "Map of CIDR endpoint name to resolved subnet IDs."
  value       = { for k, e in local.endpoints : k => e.cidr_subnet_ids if e.endpoint_type == "cidr" }
}

output "cidr_ranges" {
  description = "Map of CIDR endpoint name to configured CIDR range."
  value       = { for k, e in local.endpoints : k => e.cidr_options.cidr if e.endpoint_type == "cidr" }
}