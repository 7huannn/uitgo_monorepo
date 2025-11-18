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
  default   = ""
  sensitive = true
}

variable "preferred_azs" {
  type    = list(string)
  default = []
}

variable "notification_topic_arn" {
  type    = string
  default = ""
}
