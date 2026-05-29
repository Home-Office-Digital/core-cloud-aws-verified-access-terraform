##-----------------------------------------------------------------------------
## AWS Verified Access - Groups Sharing
##
## Owns the RAM (Resource Access Manager) sharing of the VA Groups created by
## the sibling `verified-access-groups` module out to one or more endpoints
## accounts.
##
## This module lives in the VA management account and is intentionally
## separated from `verified-access-groups` so that:
##   * VA Groups can be created once, even before any endpoints accounts exist.
##   * The set of groups any given endpoints account receives can change
##     without recreating / touching the VA Groups themselves.
##   * Adding a new endpoints account only mutates RAM share principals,
##     not the underlying group resources.
##
## Sharing model:
##   * `var.group_principals` maps a group display name -> list of 12-digit
##     account IDs that should be granted access to that group via RAM.
##   * `var.verified_access_group_arns` maps the same group display names ->
##     the VA group ARN (sourced from the verified-access-groups module).
##   * For each group with at least one principal, one aws_ram_resource_share
##     is created, one aws_ram_resource_association ties the group ARN to
##     that share, and one aws_ram_principal_association is created per
##     (group, account_id) pair.
##
## A group whose principal list is empty (or that is missing from
## `verified_access_group_arns`) is silently skipped, so dropping all
## consumers of a group cleanly destroys its share.
##-----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # shared_groups :: { group_display_name => [account_id, ...] }
  #
  # Only include groups that:
  #   1. Have at least one principal account ID, AND
  #   2. Have a known VA group ARN from the upstream module.
  #
  # Principals are deduped + sorted so terraform plan output is stable
  # regardless of how the caller orders the input list.
  # ---------------------------------------------------------------------------
  shared_groups = {
    for name, ids in var.group_principals :
    name => sort(distinct(compact(ids)))
    if length(compact(ids)) > 0 && contains(keys(var.verified_access_group_arns), name)
  }

  # ---------------------------------------------------------------------------
  # share_principal_pairs :: [{ group_name, account_id, key }, ...]
  #
  # Flattens {group => [account, ...]} into per-(group, account) pairs so we
  # can create one aws_ram_principal_association per pair via for_each.
  # The "<group>__<account>" key keeps resource addresses readable.
  # ---------------------------------------------------------------------------
  share_principal_pairs = flatten([
    for name, ids in local.shared_groups : [
      for id in ids : {
        group_name = name
        account_id = id
        key        = "${name}__${id}"
      }
    ]
  ])
}

##-----------------------------------------------------------------------------
## RAM Resource Share (one per group with non-empty principal list)
##-----------------------------------------------------------------------------
resource "aws_ram_resource_share" "group" {
  for_each = local.shared_groups

  name                      = "${var.ram_share_name_prefix}-${each.key}"
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(var.tags, {
    Name      = "${var.ram_share_name_prefix}-${each.key}"
    GroupName = each.key
  })
}

##-----------------------------------------------------------------------------
## Resource association: bind the VA group ARN to the RAM share.
##-----------------------------------------------------------------------------
resource "aws_ram_resource_association" "group" {
  for_each = local.shared_groups

  resource_arn       = var.verified_access_group_arns[each.key]
  resource_share_arn = aws_ram_resource_share.group[each.key].arn
}

##-----------------------------------------------------------------------------
## Principal association: one per (group, account_id) pair.
##-----------------------------------------------------------------------------
resource "aws_ram_principal_association" "group" {
  for_each = { for pair in local.share_principal_pairs : pair.key => pair }

  principal          = each.value.account_id
  resource_share_arn = aws_ram_resource_share.group[each.value.group_name].arn
}
