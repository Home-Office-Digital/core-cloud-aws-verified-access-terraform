output "verified_access_group_ids" {
  description = "Map of group display name -> Verified Access Group ID (vagr-...). Consumed by verified-access-endpoints to attach endpoints to a specific group."
  value       = { for name, g in aws_verifiedaccess_group.group : name => g.id }
}

output "verified_access_group_arns" {
  description = "Map of group display name -> Verified Access Group ARN. Consumed by verified-access-groups-sharing to RAM-share groups out to endpoints accounts."
  value       = { for name, g in aws_verifiedaccess_group.group : name => g.verifiedaccess_group_arn }
}

output "verified_access_group_names" {
  description = "List of group display names actually created (echoes var.groups)."
  value       = sort(tolist(local.group_names))
}
