variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "visibility_timeout" {
  type    = number
  default = 30
}

variable "retention_seconds" {
  type    = number
  default = 345600
}

variable "max_message_size" {
  type    = number
  default = 262144
}

variable "fifo" {
  type    = bool
  default = false
}

variable "kms_key_id" {
  type    = string
  default = ""
}

variable "kms_data_key_reuse_seconds" {
  type    = number
  default = 300
}

variable "receive_wait_time" {
  type    = number
  default = 10
}

variable "dead_letter_queue_arn" {
  type    = string
  default = ""
}

variable "max_receive_count" {
  type    = number
  default = 5
}
