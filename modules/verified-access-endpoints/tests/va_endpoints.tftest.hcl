mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-12345678"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      id = "subnet-12345678"
    }
  }

  mock_data "aws_lb" {
    defaults = {
      arn     = "arn:aws:elasticloadbalancing:eu-west-2:111111111111:loadbalancer/app/shared-app-lb/1234567890abcdef"
      subnets = ["subnet-a", "subnet-b"]
    }
  }

  mock_data "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:eu-west-2:111111111111:certificate/mock-certificate"
    }
  }

  mock_resource "aws_verifiedaccess_endpoint" {
    defaults = {
      endpoint_domain = "vpce.example.aws"
    }
  }
}

variables {
  vpc_name = "workload-vpc"
  verified_access_group_ids_by_name = {
    "AWSVerifiedAccess-Platform-App" = "vagr-12345678"
  }
}

run "plans_cidr_endpoint" {
  command = plan

  variables {
    endpoints = {
      "corp-access" = {
        group_name    = "AWSVerifiedAccess-Platform-App"
        endpoint_type = "cidr"
        description   = "Corporate CIDR access"
        cidr_options = {
          cidr         = "10.0.0.0/24"
          protocol     = "tcp"
          subnet_names = ["private-a", "private-b"]
          port_range = {
            from = 443
            to   = 443
          }
        }
      }
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "Expected the VPC data lookup to be wired through to outputs."
  }

  assert {
    condition     = output.endpoint_types["corp-access"] == "cidr"
    error_message = "Expected the CIDR endpoint type to be preserved in outputs."
  }

  assert {
    condition     = output.cidr_ranges["corp-access"] == "10.0.0.0/24"
    error_message = "Expected the configured CIDR range to appear in outputs."
  }

  assert {
    condition     = output.group_id_by_name["AWSVerifiedAccess-Platform-App"] == "vagr-12345678"
    error_message = "Expected the endpoint module to carry forward the group ID map."
  }
}

run "plans_load_balancer_endpoint" {
  command = plan

  variables {
    default_certificate_domain = "example.com"
    endpoints = {
      "web-app" = {
        group_name         = "AWSVerifiedAccess-Platform-App"
        endpoint_type      = "load-balancer"
        application_domain = "app.example.com"
        load_balancer_name = "shared-app-lb"
        port               = 443
      }
    }
  }

  assert {
    condition     = output.endpoint_types["web-app"] == "load-balancer"
    error_message = "Expected the load balancer endpoint type to be preserved in outputs."
  }

  assert {
    condition     = output.application_domains["web-app"] == "app.example.com"
    error_message = "Expected the application domain output for the load balancer endpoint."
  }

  assert {
    condition     = output.load_balancer_arns["web-app"] == "arn:aws:elasticloadbalancing:eu-west-2:111111111111:loadbalancer/app/shared-app-lb/1234567890abcdef"
    error_message = "Expected the mocked load balancer ARN to flow through the output map."
  }

  assert {
    condition     = length(output.load_balancer_subnet_ids["web-app"]) == 2
    error_message = "Expected the load balancer endpoint to preserve subnet IDs from the data lookup."
  }
}

run "rejects_invalid_endpoint_type" {
  command = plan

  variables {
    endpoints = {
      "bad-endpoint" = {
        group_name    = "AWSVerifiedAccess-Platform-App"
        endpoint_type = "invalid"
        cidr_options = {
          cidr         = "10.0.1.0/24"
          protocol     = "tcp"
          subnet_names = ["private-a"]
          port_range = {
            from = 443
            to   = 443
          }
        }
      }
    }
  }

  expect_failures = [
    var.endpoints,
  ]
}

run "rejects_endpoint_when_group_mapping_missing" {
  command = plan

  variables {
    verified_access_group_ids_by_name = {}
    endpoints = {
      "corp-access" = {
        group_name    = "AWSVerifiedAccess-Platform-App"
        endpoint_type = "cidr"
        cidr_options = {
          cidr         = "10.0.0.0/24"
          protocol     = "tcp"
          subnet_names = ["private-a"]
          port_range = {
            from = 443
            to   = 443
          }
        }
      }
    }
  }

  expect_failures = [
    aws_verifiedaccess_endpoint.this,
  ]
}