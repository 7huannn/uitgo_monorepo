variable "identifier" {
  description = "Unique name for the DB"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the subnet group"
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to reach the instance"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.10"
}

variable "instance_class" {
  description = "Instance size"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
