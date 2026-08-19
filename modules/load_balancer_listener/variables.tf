variable "load_balancer_arn" {
  type = string

}

variable "port" {
  type = string

}

variable "protocol" {
  type = string

}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "target_group_arn" {
  type = string
}