output "verified_access_instance_id" {
  description = "ID of the Verified Access Instance. Consumed by verified-access-group-share to attach VA Groups."
  value       = aws_verifiedaccess_instance.main.id
}

output "verified_access_instance_arn" {
  description = "ARN of the Verified Access Instance."
  value       = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:verified-access-instance/${aws_verifiedaccess_instance.main.id}"
}

output "trust_provider_id" {
  description = "ID of the IAM Identity Center (OIDC) Verified Access trust provider."
  value       = aws_verifiedaccess_trust_provider.idc.id
}

output "trust_provider_policy_reference_name" {
  description = "policy_reference_name configured on the trust provider. Consumed by verified-access-group-share when rendering Cedar policy documents."
  value       = aws_verifiedaccess_trust_provider.idc.policy_reference_name
}

# output "log_bucket_name" {
#   description = "Name of the local Verified Access log bucket (null when use_centralized_log_bucket is true)."
#   value       = var.use_centralized_log_bucket ? null : aws_s3_bucket.va_log_bucket[0].id
# }

# output "log_group_name" {
#   description = "Name of the CloudWatch log group used for Verified Access logging."
#   value       = aws_cloudwatch_log_group.va_logs.name
# }

# output "log_group_arn" {
#   description = "ARN of the CloudWatch log group used for Verified Access logging."
#   value       = aws_cloudwatch_log_group.va_logs.arn
# }
