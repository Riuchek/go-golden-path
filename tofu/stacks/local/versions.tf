terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }

  # LocalStack is the cloud. State stays on disk next to this stack so a
  # laptop demo does not depend on a remote backend chicken-and-egg.
}

provider "aws" {
  region                      = var.region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    cloudwatch     = var.localstack_endpoint
    cloudwatchlogs = var.localstack_endpoint
    ec2            = var.localstack_endpoint
    ecr            = var.localstack_endpoint
    ecs            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    s3             = var.localstack_endpoint
    sts            = var.localstack_endpoint
    xray           = var.localstack_endpoint
  }
}
