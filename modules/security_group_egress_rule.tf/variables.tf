variable "security_group_id" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "ip_protocol" {
  type = string
}

variable "from_port" {
  type = number
}

variable "to_port" {
  type = number
}

variable "destination_type" {
  type        = string
  description = "Destination type: cidr_ipv4, prefix_list or security_group."

  validation {
    condition = contains([
      "cidr_ipv4",
      "prefix_list",
      "security_group"
    ], var.destination_type)

    error_message = "destination_type must be cidr_ipv4, prefix_list or security_group."
  }
}

variable "destination" {
  type        = string
  description = "CIDR, prefix list ID or security group ID."
}