terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "demo-platform"
      ManagedBy  = "terraform"
      Repository = "eks-observability-stack"
    }
  }
}
