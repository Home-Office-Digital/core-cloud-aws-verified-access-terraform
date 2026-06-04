# core-cloud-aws-verified-access-terraform

Terraform modules for building and operating AWS Verified Access across a
management account and one or more workload (endpoint) accounts.

## What This Repository Provides

This repository is split into reusable modules that mirror the Verified Access
operating model:

- A central Verified Access instance and IAM Identity Center trust provider.
- Verified Access groups with Cedar policies.
- RAM-based sharing of groups to endpoint accounts.
- Endpoint creation in workload accounts (ALB and CIDR endpoint types).
- Security scanning in CI (Checkov and SonarQube).

## Module Overview

### modules/verified-access-instance

Creates and manages:

- `aws_verifiedaccess_instance`
- `aws_verifiedaccess_trust_provider` (IAM Identity Center user trust)
- Trust provider attachment to the instance
- Optional WAFv2 Web ACL association
- Verified Access logging resources (KMS, CloudWatch log group, S3 buckets,
	bucket policies, lifecycle)

Key outputs used by downstream modules:

- `verified_access_instance_id`
- `trust_provider_policy_reference_name`

### modules/verified-access-groups

Creates one Verified Access group per entry in `var.groups` and applies a
Cedar policy per group.

- Default policy allows when the IDC token claim includes the matching group
	name (`context.<policy_reference_name>.groups has "<group-name>"`).
- Optional `policy_documents` lets you override policy by group.

Key output used by downstream modules:

- `verified_access_group_arns`

### modules/verified-access-groups-sharing

Shares groups to other AWS accounts using AWS RAM.

- Input: `verified_access_group_arns` and `group_principals`
- Creates one RAM share per group with consumers
- Associates each target account ID as a RAM principal

Useful outputs:

- `ram_resource_share_arns`
- `verified_access_group_ids`
- `endpoints_config_snippets` (copy/paste mapping for endpoints account config)

### modules/verified-access-endpoints

Creates endpoints in workload accounts and attaches them to shared Verified
Access groups.

Supported endpoint types:

- `load-balancer`: resolves ALB and ACM certificate
- `cidr`: creates CIDR-based endpoint with protocol/port-range settings

Also creates per-endpoint security groups and validates key preconditions (for
example: group mapping exists, required cert exists for load balancer endpoint).

## Recommended Apply Sequence

1. Apply `verified-access-instance` in the management account.
2. Apply `verified-access-groups` using remote-state outputs from step 1.
3. Apply `verified-access-groups-sharing` to share groups to endpoint accounts.
4. Apply `verified-access-endpoints` in each workload account using the mapped
	 `vagr-*` IDs.

This separation keeps group lifecycle independent from endpoint-account
onboarding and simplifies cross-account operations.

## Inputs and Configuration Pattern

The modules are designed to be composed from Terragrunt/Terraform remote state:

- Instance module exports IDs and policy reference name.
- Groups module consumes instance outputs and exports group ARNs/IDs.
- Sharing module consumes group ARNs and account-principal mapping.
- Endpoints module consumes group IDs by name.

## Security and Compliance Notes

- Logging is encrypted and retention-aware (CloudWatch retention validation).
- S3 buckets enforce HTTPS-only access via bucket policy.
- Public access blocks are enabled for log buckets.
- Existing inline `checkov:skip` annotations document justified exceptions.

## Running Tests Locally

Prerequisites:

- Terraform CLI installed (1.9+ recommended)
- `jq` installed (optional, useful for parsing JSON test output)

Run tests for a single module:

```bash
terraform -chdir=modules/verified-access-groups init -backend=false
terraform -chdir=modules/verified-access-groups fmt -check -recursive
terraform -chdir=modules/verified-access-groups validate
terraform -chdir=modules/verified-access-groups test
```

Run tests for all modules with Terraform tests:

```bash
for m in modules/*; do
	if find "$m" -maxdepth 3 -type f -name "*.tftest.hcl" | grep -q .; then
		echo "=== Testing $m ==="
		terraform -chdir="$m" init -backend=false
		terraform -chdir="$m" fmt -check -recursive
		terraform -chdir="$m" validate
		terraform -chdir="$m" test
	fi
done
```

Notes:

- Run `init` before `test` for each module to ensure provider plugins are available.
- Run commands from the module root (for example `modules/verified-access-groups`), not from `modules/.../tests`.
- These tests are plan-focused and use Terraform test mocks/overrides where configured.

## CI / SAST Workflow

Workflow file: `.github/workflows/sast-scans.yaml`

On pushes and pull requests affecting `modules/**`, CI runs:

1. Checkov reusable workflow
2. SonarQube reusable workflow

Reusable workflows are SHA-pinned for supply-chain safety.

## Repository Structure

```text
modules/
	verified-access-instance/
	verified-access-groups/
	verified-access-groups-sharing/
	verified-access-endpoints/
```
