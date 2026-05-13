##-----------------------------------------------------------------------------
## AWS Verified Access - Instance
##
## Creates the Verified Access Instance, the IAM Identity Center (OIDC) trust
## provider, attaches the trust provider to the instance, and (optionally)
## associates a WAFv2 Web ACL with the instance.
##
## Verified Access Groups, RAM shares, and IdC group lookups live in the
## verified-access-group-share module, which depends on this module's outputs
## via Terragrunt remote state.
##-----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_wafv2_web_acl" "existing" {
  count = var.enable_waf ? 1 : 0

  name  = var.waf_web_acl_name
  scope = var.waf_web_acl_scope
}

##-----------------------------------------------------------------------------
## 1. Verified Access Trust Provider (IAM Identity Center / OIDC org-shared)
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_trust_provider" "idc" {
  trust_provider_type      = "user"
  user_trust_provider_type = "iam-identity-center"
  policy_reference_name    = var.policy_reference_name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-idc-trust"
  })
}

##-----------------------------------------------------------------------------
## 2. Verified Access Instance
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_instance" "main" {
  description = "Perimeter Verified Access Instance"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-instance"
  })
}

##-----------------------------------------------------------------------------
## 3. Attach Trust Provider to Instance
##-----------------------------------------------------------------------------
resource "aws_verifiedaccess_instance_trust_provider_attachment" "att" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.main.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.idc.id
}

##-----------------------------------------------------------------------------
## 4. (Optional) WAF association
##-----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "va_assoc" {
  count = var.enable_waf ? 1 : 0

  resource_arn = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:verified-access-instance/${aws_verifiedaccess_instance.main.id}"
  web_acl_arn  = data.aws_wafv2_web_acl.existing[0].arn
}
