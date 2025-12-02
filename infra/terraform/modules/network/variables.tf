variable "name" {
  description = "Prefix for named resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR range for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Base tags to apply"
  type        = map(string)
  default     = {}
}
