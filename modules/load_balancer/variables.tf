variable "load_balancer_type" {
  type        = string
  default     = "application"
  description = "Type of the load balancer"

}

variable "name" {
  type        = string
  description = "name of the load balancer"
}

variable "internal" {
  type        = bool
  description = "interno ou não"

}

variable "tags" {
  type        = map(string)
  description = "tags"

}

variable "subnets_ids" {
  type        = list(string)
  description = "Subnets that will be associated with the load balancer"

}

variable "security_group_ids" {
  type        = list(string)
  description = "security group that is associated"

}