variable "name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "security_group_ids" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 6
}

variable "desired_capacity" {
  type    = number
  default = 3
}

variable "cpu_target" {
  type    = number
  default = 60
}

variable "user_data" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
