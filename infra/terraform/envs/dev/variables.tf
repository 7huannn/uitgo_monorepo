variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project prefix"
  type        = string
  default     = "uitgo"
}

variable "db_username" {
  description = "Shared DB admin user"
  type        = string
  default     = "uitgo"
}

variable "db_password" {
  description = "Shared DB admin password"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.60.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.60.1.0/24", "10.60.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.60.11.0/24", "10.60.12.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "container_registry" {
  description = "Container registry base (e.g. ghcr.io/uitgo)"
  type        = string
  default     = "ghcr.io/uitgo"
}

variable "container_registry_username" {
  description = "Optional registry username for pulling private images"
  type        = string
  default     = ""
}

variable "container_registry_password" {
  description = "Optional registry password/token for pulling private images"
  type        = string
  default     = ""
  sensitive   = true
}

variable "backend_image_tag" {
  description = "Tag for backend service Docker images"
  type        = string
  default     = "latest"
}

variable "trip_service_ami" {
  description = "AMI ID for trip-service instances"
  type        = string
  default     = "ami-xxxxxxxx"
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (REQUIRED for production)"
  type        = string
  default     = ""
}

variable "jwt_secret" {
  description = "JWT signing secret for backend services (REQUIRED - no default for security)"
  type        = string
  sensitive   = true
  # SECURITY: No default value - must be provided via tfvars or environment
  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "jwt_secret must be at least 32 characters for security."
  }
}

variable "refresh_token_encryption_key" {
  description = "32-byte key for refresh token encryption (REQUIRED - no default for security)"
  type        = string
  sensitive   = true
  # SECURITY: No default value - must be provided via tfvars or environment
  validation {
    condition     = length(var.refresh_token_encryption_key) == 32
    error_message = "refresh_token_encryption_key must be exactly 32 characters."
  }
}

variable "internal_api_key" {
  description = "Internal API key used between services (REQUIRED - no default for security)"
  type        = string
  sensitive   = true
  # SECURITY: No default value - must be provided via tfvars or environment
  validation {
    condition     = length(var.internal_api_key) >= 24
    error_message = "internal_api_key must be at least 24 characters for security."
  }
}

variable "cors_allowed_origins" {
  description = "Comma separated list of allowed origins"
  type        = string
  default     = "https://app.uitgo.vn"
}
