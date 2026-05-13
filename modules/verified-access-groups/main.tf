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
}

##-----------------------------------------------------------------------------
## Verified Access Groups (one per entry in var.groups)
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_group" "group" {
  for_each = local.group_names

  verifiedaccess_instance_id = var.verified_access_instance_id
  description                = "Verified Access Group ${each.key}"

  policy_document = <<-EOT
    permit(principal, action, resource)
    when {
        context.${var.policy_reference_name}.groups has "${each.key}"
    };
  EOT

  tags = merge(var.tags, {
    Name      = each.key
    GroupName = each.key
  })
}
