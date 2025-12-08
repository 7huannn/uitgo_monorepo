variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "engine_version" {
  type    = string
  default = "7.1"
}

variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}

variable "cluster_count" {
  type    = number
  default = 1
}

variable "port" {
  type    = number
  default = 6379
}

variable "maintenance_window" {
  type    = string
  default = "sun:05:00-sun:06:00"
}

variable "auth_token" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.auth_token) >= 16 && length(var.auth_token) <= 128
    error_message = "auth_token must contain from 16 to 128 characters."
  }

  validation {
    condition     = length(regexall("[@\"/]", var.auth_token)) == 0
    error_message = "auth_token may not contain @, \", or /."
  }
}

variable "preferred_azs" {
  type    = list(string)
  default = []
}

variable "notification_topic_arn" {
  type    = string
  default = ""
}
