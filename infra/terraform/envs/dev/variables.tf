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
  description = "Optional ACM certificate ARN for HTTPS listener"
  type        = string
  default     = ""
}

variable "jwt_secret" {
  description = "JWT signing secret for backend services"
  type        = string
  default     = "uitgo-prod-secret-change-me"
  sensitive   = true
}

variable "refresh_token_encryption_key" {
  description = "32-byte key for refresh token encryption"
  type        = string
  default     = "***REMOVED***"
  sensitive   = true
}

variable "internal_api_key" {
  description = "Internal API key used between services"
  type        = string
  default     = "uitgo-internal-secret"
  sensitive   = true
}

variable "cors_allowed_origins" {
  description = "Comma separated list of allowed origins"
  type        = string
  default     = "https://app.uitgo.vn"
}
