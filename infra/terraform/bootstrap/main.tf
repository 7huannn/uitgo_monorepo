# Bootstrap configuration for GitHub OIDC
# Run this FIRST to set up OIDC authentication for GitHub Actions
#
# Usage:
#   cd infra/terraform/bootstrap
#   terraform init
#   terraform apply -var="github_org=7huannn" -var="github_repo=uitgo_monorepo"
#
# After apply, add these outputs to GitHub Secrets:
#   - AWS_ROLE_ARN
#   - TF_STATE_BUCKET
#   - TF_LOCK_TABLE

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # NOTE: For bootstrap, we use local state
  # After bootstrap, you can migrate to S3 backend
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "uitgo"
}

module "github_oidc" {
  source = "../modules/github-oidc"
  
  project_name = var.project_name
  github_org   = var.github_org
  github_repo  = var.github_repo
  
  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "github-actions-oidc"
  }
}

output "github_actions_role_arn" {
  description = "Add this to GitHub Secrets as AWS_ROLE_ARN"
  value       = module.github_oidc.github_actions_role_arn
}

output "terraform_state_bucket" {
  description = "Add this to GitHub Secrets as TF_STATE_BUCKET"
  value       = module.github_oidc.terraform_state_bucket
}

output "terraform_lock_table" {
  description = "Add this to GitHub Secrets as TF_LOCK_TABLE"
  value       = module.github_oidc.terraform_lock_table
}

output "next_steps" {
  description = "Instructions for completing setup"
  value       = <<-EOT
    
    ========================================
    GitHub OIDC Setup Complete!
    ========================================
    
    Add these to GitHub Repository Secrets:
    (Settings → Secrets and variables → Actions → New repository secret)
    
    1. AWS_ROLE_ARN = ${module.github_oidc.github_actions_role_arn}
    2. TF_STATE_BUCKET = ${module.github_oidc.terraform_state_bucket}
    3. TF_LOCK_TABLE = ${module.github_oidc.terraform_lock_table}
    
    After adding secrets, update infra/terraform/envs/dev/main.tf
    to use S3 backend:
    
    terraform {
      backend "s3" {
        bucket         = "${module.github_oidc.terraform_state_bucket}"
        key            = "uitgo/dev/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${module.github_oidc.terraform_lock_table}"
        encrypt        = true
      }
    }
    
  EOT
}
