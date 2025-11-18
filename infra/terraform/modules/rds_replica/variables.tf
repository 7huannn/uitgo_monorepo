variable "identifier" {
  type = string
}

variable "source_identifier" {
  type = string
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "availability_zone" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
