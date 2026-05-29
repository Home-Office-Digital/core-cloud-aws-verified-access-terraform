##-----------------------------------------------------------------------------
## AWS Verified Access - Groups
##
## Creates one Verified Access Group per entry in var.groups, attached to the
## Verified Access Instance owned by the verified-access-instance module.
##
## The group name (resource Name tag) and the IAM Identity Center display name
## are assumed to be identical, so each entry in var.groups is used directly as
## both the VA group's Name tag and the literal string referenced in the
## Cedar policy context check:
##
##   permit(principal, action, resource)
##   when {
##       context.<policy_reference_name>.groups has "<group-name>"
##   };
##
## RAM sharing of these groups out to endpoints accounts is owned by the
## sibling `verified-access-groups-sharing` module so that group creation can
## evolve independently of who they're shared with.
##-----------------------------------------------------------------------------

locals {
  # Use the full group name as the for_each key so resource addresses are
  # stable and human-readable (e.g. .group["AWSVerifiedAccess-Platform-App"]).
  group_names = toset(var.groups)

  # Default Cedar policy used when a group has no entry in var.policy_documents.
  # Permits the principal when their IDC token's groups claim contains the
  # matching group name. Kept as a per-group map so the resource body can do a
  # simple lookup instead of computing the heredoc inline.
  default_policies = {
    for name in local.group_names :
    name => <<-EOT
      permit(principal, action, resource)
      when {
          context.${var.policy_reference_name}.groups has "${name}"
      };
    EOT
  }

  # Final policy per group: explicit override from var.policy_documents wins,
  # otherwise the default template above.
  group_policies = {
    for name in local.group_names :
    name => lookup(var.policy_documents, name, local.default_policies[name])
  }
}

##-----------------------------------------------------------------------------
## Verified Access Groups (one per entry in var.groups)
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_group" "group" {
  for_each = local.group_names

  verifiedaccess_instance_id = var.verified_access_instance_id
  description                = "Verified Access Group ${each.key}"
  policy_document            = local.group_policies[each.key]

  tags = merge(var.tags, {
    Name      = each.key
    GroupName = each.key
  })
}
