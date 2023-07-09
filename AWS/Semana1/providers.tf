terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      ENVIRONMENT = local.environment
      PROJECT     = local.project_name
      TEAM        = local.team_name
      DEPLOYMENT  = local.global_identifier
      CRITICAL    = local.is_critical_string
      SEMANA      = local.week
      MANAGED     = "Terraform"
    }
  }
}