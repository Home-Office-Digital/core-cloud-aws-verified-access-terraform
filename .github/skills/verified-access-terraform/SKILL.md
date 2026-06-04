---
name: verified-access-terraform
description: 'Use when working on AWS Verified Access Terraform in this repo: module wiring, apply order, remote-state handoff, RAM group sharing, endpoint mapping, and CI SAST workflow updates.'
argument-hint: 'Task type (for example: summarize, validate wiring, troubleshoot plan, update module docs)'
user-invocable: true
---

# Verified Access Terraform Workflow

## When to Use
- Explaining how modules in this repository fit together.
- Validating cross-module inputs and outputs.
- Troubleshooting endpoint or group mapping issues.
- Updating documentation for module usage and apply sequence.
- Reviewing CI workflow changes for Checkov and SonarQube scans.

## What This Skill Covers
- Module responsibilities for:
  - verified-access-instance
  - verified-access-groups
  - verified-access-groups-sharing
  - verified-access-endpoints
- Recommended deployment/apply order.
- Common integration checks for remote-state output handoff.
- Common failure points in YAML workflow wiring for reusable workflows.

## Procedure
1. Identify which module the task affects.
2. Confirm dependencies from upstream module outputs.
3. Validate that names and IDs line up across modules:
   - policy reference name
   - verified access group IDs and ARNs
   - endpoint group name to ID mapping
4. If touching CI:
   - ensure reusable workflows are called at the correct scope
   - ensure pinned commit SHAs are used
   - verify secrets naming matches repository secrets
5. Summarize required changes with exact file paths.

## Quick Checks
- Group creation:
  - var.groups has unique entries.
  - Optional policy_documents keys are a subset of var.groups.
- Group sharing:
  - group_principals contains 12-digit account IDs.
  - verified_access_group_arns are valid verified-access-group ARNs.
- Endpoints:
  - each endpoint has endpoint_type set to load-balancer or cidr.
  - group_name is present in verified_access_group_ids_by_name.
  - load-balancer endpoints have a resolvable ACM certificate.
- Instance:
  - optional WAF settings are only used when enable_waf is true.
  - CloudWatch retention is >= 365 days.

## Notes
- Keep module boundaries clear: do not mix group sharing logic into group creation logic.
- Prefer small, focused changes and keep outputs stable for downstream consumers.
