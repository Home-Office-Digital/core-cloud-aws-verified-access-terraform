data "aws_vpc" "workload" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_acm_certificate" "default" {
  count = var.default_certificate_domain != null ? 1 : 0

  domain      = var.default_certificate_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_lb" "endpoint" {
  for_each = {
    for name, e in var.endpoints : name => e
    if e.endpoint_type == "load-balancer"
  }

  name = each.value.load_balancer_name
}

locals {
  cidr_subnet_names = toset(flatten([
    for _, e in var.endpoints :
    e.endpoint_type == "cidr" && e.cidr_options != null ? e.cidr_options.subnet_names : []
  ]))
}

data "aws_subnet" "cidr_endpoint" {
  for_each = local.cidr_subnet_names

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

locals {
  vpc_id           = data.aws_vpc.workload.id
  default_cert_arn = length(data.aws_acm_certificate.default) > 0 ? data.aws_acm_certificate.default[0].arn : null

  endpoints = {
    for name, e in var.endpoints :
    name => merge(e, {
      certificate_arn          = e.endpoint_type == "load-balancer" ? local.default_cert_arn : null
      domain_prefix            = coalesce(e.endpoint_domain_prefix, "${var.name_prefix}-${name}")
      verified_access_group_id = lookup(var.verified_access_group_ids_by_name, e.group_name, null)

      load_balancer_arn = e.endpoint_type == "load-balancer" ? data.aws_lb.endpoint[name].arn : null
      lb_subnet_ids     = e.endpoint_type == "load-balancer" ? data.aws_lb.endpoint[name].subnets : []

      cidr_subnet_ids = e.endpoint_type == "cidr" && e.cidr_options != null ? [
        for subnet_name in e.cidr_options.subnet_names :
        data.aws_subnet.cidr_endpoint[subnet_name].id
      ] : []
    })
  }
}

resource "aws_security_group" "endpoint" {
  for_each = local.endpoints

  name        = "${var.name_prefix}-${each.key}-sg"
  description = "Verified Access endpoint ${each.key}"
  vpc_id      = local.vpc_id

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-${each.key}-sg"
    EndpointName = each.key
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_any" {
  for_each = local.endpoints

  security_group_id = aws_security_group.endpoint[each.key].id
  description       = "Allow any protocol, any port, from anywhere"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-${each.key}-ingress-any"
    EndpointName = each.key
  })
}

resource "aws_vpc_security_group_egress_rule" "endpoint_any" {
  for_each = local.endpoints

  security_group_id = aws_security_group.endpoint[each.key].id
  description       = "Allow any protocol, any port, to anywhere"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-${each.key}-egress-any"
    EndpointName = each.key
  })
}

resource "aws_verifiedaccess_endpoint" "this" {
  for_each = local.endpoints

  verified_access_group_id = each.value.verified_access_group_id
  endpoint_domain_prefix   = each.value.domain_prefix
  endpoint_type            = each.value.endpoint_type
  attachment_type          = "vpc"
  security_group_ids       = [aws_security_group.endpoint[each.key].id]
  description              = coalesce(each.value.description, "VA endpoint ${each.key}")
  policy_document          = each.value.policy_document

  application_domain     = each.value.endpoint_type == "load-balancer" ? trimsuffix(lower(each.value.application_domain), ".") : null
  domain_certificate_arn = each.value.endpoint_type == "load-balancer" ? each.value.certificate_arn : null

  dynamic "load_balancer_options" {
    for_each = each.value.endpoint_type == "load-balancer" ? [1] : []

    content {
      load_balancer_arn = each.value.load_balancer_arn
      port              = 443
      protocol          = "https"
      subnet_ids        = each.value.lb_subnet_ids
    }
  }

  dynamic "cidr_options" {
    for_each = each.value.endpoint_type == "cidr" && each.value.cidr_options != null ? [each.value.cidr_options] : []

    content {
      cidr       = cidr_options.value.cidr
      protocol   = cidr_options.value.protocol
      subnet_ids = each.value.cidr_subnet_ids

      port_range {
        from_port = cidr_options.value.port_range.from
        to_port   = cidr_options.value.port_range.to
      }
    }
  }

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-${each.key}"
    EndpointName = each.key
    EndpointType = each.value.endpoint_type
  })

  lifecycle {
    precondition {
      condition     = each.value.endpoint_type != null
      error_message = "Endpoint '${each.key}' has no endpoint_type. Set 'endpointType' on the YAML endpoint (or set 'loadBalancerName' so the platform entry can default it to 'load-balancer')."
    }

    precondition {
      condition     = each.value.endpoint_type != null && contains(["load-balancer", "cidr"], each.value.endpoint_type)
      error_message = "Endpoint '${each.key}' endpoint_type='${coalesce(each.value.endpoint_type, "<null>")}' must be one of: load-balancer, cidr."
    }

    precondition {
      condition     = each.value.verified_access_group_id != null
      error_message = "Endpoint '${each.key}' references group_name '${each.value.group_name}', but that group is missing from var.verified_access_group_ids_by_name."
    }

    precondition {
      condition     = each.value.endpoint_type != "load-balancer" || each.value.certificate_arn != null
      error_message = "Endpoint '${each.key}' has no certificate. Provide var.default_certificate_domain."
    }
  }
}