output "ram_resource_share_arns" {
  description = "Map of group display name -> aws_ram_resource_share ARN. Only populated for groups with at least one principal."
  value       = { for k, s in aws_ram_resource_share.group : k => s.arn }
}

output "ram_share_principals" {
  description = "Map of group display name -> sorted list of account IDs the group is RAM-shared with."
  value       = { for k, ids in local.shared_groups : k => sort(ids) }
}

output "ram_share_pair_keys" {
  description = "Sorted list of '<group>__<account_id>' pair keys actually associated. Useful for diffing in CI."
  value       = sort([for p in local.share_principal_pairs : p.key])
}

##-----------------------------------------------------------------------------
## Convenience outputs: ready-to-paste endpoints config snippets.
##
## After `verified-access-groups-sharing` applies, the operator needs to copy
## the resulting vagr-* IDs into each consumer account's
## verifiedAccessGroupIdsByName YAML field. These outputs surface that mapping
## directly so it can be copy/pasted from the apply output - no AWS console
## clicking, no aws-cli round-trip.
##
## verified_access_group_ids parses the trailing "vagr-XXXX" segment from each
## input ARN. endpoints_config_snippets pivots {group: [account_ids]} into
## {account_name: {group: vagr-id}} using principal_account_names_by_id.
##-----------------------------------------------------------------------------
locals {
  # AWS VA group IDs in real ARNs are 17 lowercase hex chars, but match
  # against the broader [a-z0-9] alphabet so the parser doesn't reject
  # future ID-format changes or non-hex mock ARNs in plan-time validation.
  verified_access_group_ids = {
    for name, arn in var.verified_access_group_arns :
    name => try(regex("vagr-[a-z0-9]+$", arn), null)
  }

  # Flatten shared_groups to [{account_id, group_name, vagr_id}, ...]
  per_principal_entries = flatten([
    for gn, ids in local.shared_groups : [
      for id in ids : {
        account_id   = id
        account_name = lookup(var.principal_account_names_by_id, id, id)
        group_name   = gn
        vagr_id      = local.verified_access_group_ids[gn]
      }
    ]
  ])

  # Pivot to {account_name: {group_name: vagr-id}}
  snippets_by_account = {
    for account_name in distinct([for e in local.per_principal_entries : e.account_name]) :
    account_name => {
      for e in local.per_principal_entries : e.group_name => e.vagr_id
      if e.account_name == account_name
    }
  }
}

output "verified_access_group_ids" {
  description = "Map of group display name -> Verified Access Group ID (vagr-...), parsed from the input ARNs."
  value       = local.verified_access_group_ids
}

output "endpoints_config_snippets" {
  description = <<-EOT
    Map of account name -> {group_name: vagr-id} ready to paste under
    verifiedAccessGroupIdsByName in each endpoints account's YAML record.

    Operator flow after this module applies:
      1. terraform output -json endpoints_config_snippets
      2. For each account_name key, copy the inner map under
         verifiedAccessGroupIdsByName in core-cloud-accounts-config.
      3. Re-run the pipeline; the endpoints terragrunt now resolves the IDs.

    Accounts whose ID isn't present in var.principal_account_names_by_id
    appear in this output keyed by their raw account ID instead of name.
  EOT
  value       = local.snippets_by_account
}
