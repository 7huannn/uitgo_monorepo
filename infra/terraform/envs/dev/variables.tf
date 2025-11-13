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
